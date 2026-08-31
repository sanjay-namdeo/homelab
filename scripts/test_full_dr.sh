#!/usr/bin/env bash
# ==============================================================================
# Homelab Full Disaster Recovery Validation Script
# ==============================================================================
# Orchestrates the existing scripts in sequence to validate the full DR cycle:
#
#   Phase 1 — deploy_stack.sh     : bring all containers up
#   Phase 2 — healthcheck.sh      : full 6-tier diagnostic
#   Phase 3 — backup_homelab.sh   : snapshot + Cloudflare R2 upload + verify
#   Phase 4 — DR drill            : stop → wipe → restore_homelab.sh →
#                                   SQLite integrity → deploy_stack.sh →
#                                   re-verify containers + endpoints
#
# Usage:  sudo bash /opt/homelab/scripts/test_full_dr.sh [dev1|dev2]
# Log:    /opt/homelab/data/backups/dr_test_<timestamp>.log
#
# Design notes:
#   - No `set -e`: failures are captured as PASS/WARN/FAIL counts; the script
#     continues and exits non-zero only in the final summary.
#   - Sub-scripts (deploy/backup/restore) each have their own `set -euo pipefail`.
#     We capture their exit via PIPESTATUS[0] after `cmd 2>&1 | tee -a logfile`.
#   - Symlink check covers both hosts regardless of which archive is restored,
#     because restore_homelab.sh now creates both symlinks in both code paths.
# ==============================================================================

set -uo pipefail

HOMELAB_DIR="/opt/homelab"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
mkdir -p "${HOMELAB_DIR}/data/backups"
LOG_FILE="${HOMELAB_DIR}/data/backups/dr_test_${TIMESTAMP}.log"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

PASS_COUNT=0; WARN_COUNT=0; FAIL_COUNT=0

log()    { echo -e "$1" | tee -a "${LOG_FILE}"; }
pass()   { ((PASS_COUNT++));  log "  [${GREEN}✔ PASS${NC}] $1"; }
warn()   { ((WARN_COUNT++));  log "  [${YELLOW}⚠ WARN${NC}] $1"; }
fail()   { ((FAIL_COUNT++));  log "  [${RED}✖ FAIL${NC}] $1"; }
header() { log "\n${CYAN}${BOLD}════════════════════════════════════════${NC}";
           log "${CYAN}${BOLD}  $1${NC}";
           log "${CYAN}${BOLD}════════════════════════════════════════${NC}"; }
phase()  { log "\n${BLUE}${BOLD}▶ $1${NC}"; }

# ── Root check ───────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Run with: sudo bash /opt/homelab/scripts/test_full_dr.sh [dev1|dev2]"
    exit 1
fi

# ── Host detection ────────────────────────────────────────────────────────────
# Mirrors the same detection logic used by deploy_stack.sh and backup_homelab.sh
TARGET_HOST="${1:-}"
if [[ -z "${TARGET_HOST}" ]]; then
    HOSTNAME_S=$(hostname -s 2>/dev/null || echo "")
    if [[ "${HOSTNAME_S}" == "dev2" ]]; then
        TARGET_HOST="dev2"
    else
        TARGET_HOST="dev1"
    fi
fi

header "Homelab Full DR Validation — Host: ${TARGET_HOST}"
log "Started : $(date)"
log "Log file: ${LOG_FILE}"

# ── Load env ──────────────────────────────────────────────────────────────────
# Re-usable: called again after Phase 4 wipes and restores .env
ENV_FILE="${HOMELAB_DIR}/.env"
load_env() {
    if [[ -f "${ENV_FILE}" ]]; then
        set -a
        # shellcheck disable=SC1090
        source "${ENV_FILE}"
        set +a
        return 0
    fi
    return 1
}

if load_env; then
    pass "Root .env loaded (${ENV_FILE})"
else
    fail "Root .env not found — cannot continue"
    exit 1
fi

# ── Expected containers (mirrors healthcheck.sh) ─────────────────────────────
if [[ "${TARGET_HOST}" == "dev2" ]]; then
    EXPECTED_CONTAINERS=("obsidian_web" "beszel" "beszel_agent" "gatus")
else
    EXPECTED_CONTAINERS=("vaultwarden" "adguardhome" "caddy" "obsidian_webdav" "beszel_agent")
fi

# ── run_script: run a sub-script through tee, capture real exit code ─────────
# Usage: run_script <label> <script> [args...]
# Returns the sub-script's exit code (not tee's).
run_script() {
    local label="$1"; shift
    log "\n  Running: $*"
    # Use a temp file to ferry the exit code out of the pipe subshell
    local _exit_file
    _exit_file=$(mktemp)
    { bash "$@" 2>&1; echo $? > "${_exit_file}"; } | tee -a "${LOG_FILE}"
    local _rc
    _rc=$(cat "${_exit_file}")
    rm -f "${_exit_file}"
    return "${_rc}"
}

# ── check_containers: mirrors healthcheck.sh container loop ──────────────────
check_containers() {
    local label="$1"
    for c in "${EXPECTED_CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${c}$"; then
            STATUS=$(docker inspect --format='{{.State.Status}}' "${c}" 2>/dev/null || echo "unknown")
            HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${c}" 2>/dev/null || echo "none")
            if [[ "${HEALTH}" == "healthy" ]]; then
                pass "${label} '${c}': ${STATUS} (health: healthy)"
            elif [[ "${HEALTH}" == "starting" ]]; then
                warn "${label} '${c}': running (healthcheck starting)"
            elif [[ "${STATUS}" == "running" ]]; then
                pass "${label} '${c}': running"
            else
                fail "${label} '${c}': ${STATUS}"
            fi
        else
            fail "${label} '${c}': NOT running"
        fi
    done
}

# ── http_spot_checks: mirrors healthcheck.sh endpoint verification ────────────
# Uses local HTTP (no TLS) since we run from within the host.
# Ports and paths match the docker-compose port bindings exactly.
http_spot_checks() {
    local label="$1"
    if [[ "${TARGET_HOST}" == "dev1" ]]; then
        # Vaultwarden: 127.0.0.1:8080 → container :80
        VW=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:8080/alive" 2>/dev/null || echo "000")
        [[ "${VW}" == "200" ]] && pass "${label} Vaultwarden :8080/alive → HTTP ${VW}" \
                               || warn "${label} Vaultwarden :8080/alive → HTTP ${VW}"

        # AdGuard Home: 127.0.0.1:8081
        AG=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:8081/login.html" 2>/dev/null || echo "000")
        [[ "${AG}" == "200" ]] && pass "${label} AdGuard :8081/login.html → HTTP ${AG}" \
                               || warn "${label} AdGuard :8081/login.html → HTTP ${AG}"

        # Obsidian WebDAV: 127.0.0.1:8082 (needs Basic Auth)
        DAV_PASS=$(grep '^WEBDAV_PASSWORD=' "${ENV_FILE}" 2>/dev/null | cut -d= -f2- || echo "")
        if [[ -n "${DAV_PASS}" ]]; then
            DAV=$(curl -s -u "obsidian:${DAV_PASS}" -o /dev/null -w "%{http_code}" --max-time 5 \
                  "http://127.0.0.1:8082/data/" 2>/dev/null || echo "000")
            [[ "${DAV}" =~ ^(200|207|301)$ ]] && pass "${label} WebDAV :8082/data/ → HTTP ${DAV}" \
                                               || warn "${label} WebDAV :8082/data/ → HTTP ${DAV}"
        else
            warn "${label} WEBDAV_PASSWORD not in .env — skipping WebDAV check"
        fi

        # Caddy HTTP redirect: :80 should redirect to HTTPS
        CADDY=$(curl -s -I --max-time 5 "http://127.0.0.1/" 2>/dev/null | grep -i "^Location:" || echo "")
        [[ "${CADDY}" =~ "https://" ]] && pass "${label} Caddy :80 → HTTPS redirect active" \
                                       || warn "${label} Caddy :80 redirect not detected (${CADDY:-no Location header})"
    else
        # Gatus: 127.0.0.1:8085 — healthcheck endpoint is /health (matches Docker healthcheck)
        GT=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:8085/health" 2>/dev/null || echo "000")
        [[ "${GT}" == "200" ]] && pass "${label} Gatus :8085/health → HTTP ${GT}" \
                               || warn "${label} Gatus :8085/health → HTTP ${GT}"

        # Flatnotes: 127.0.0.1:8083
        FN=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:8083/" 2>/dev/null || echo "000")
        [[ "${FN}" =~ ^(200|302)$ ]] && pass "${label} Flatnotes :8083/ → HTTP ${FN}" \
                                     || warn "${label} Flatnotes :8083/ → HTTP ${FN}"

        # Beszel Hub: 127.0.0.1:8090
        BZ=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:8090/" 2>/dev/null || echo "000")
        [[ "${BZ}" =~ ^(200|302)$ ]] && pass "${label} Beszel Hub :8090/ → HTTP ${BZ}" \
                                     || warn "${label} Beszel Hub :8090/ → HTTP ${BZ}"
    fi
}

# ── check_sqlite: matches restore_homelab.sh PRAGMA integrity_check ──────────
check_sqlite() {
    local db="$1" label="$2"
    if [[ ! -f "${db}" ]]; then
        warn "${label}: file not found — may not exist on a fresh host"
        return
    fi
    if python3 - <<PYEOF 2>/dev/null
import sqlite3, sys
con = sqlite3.connect("${db}")
res = con.execute("PRAGMA integrity_check;").fetchall()
con.close()
sys.exit(0 if res == [("ok",)] else 1)
PYEOF
    then
        pass "${label}: SQLite integrity_check OK"
    else
        fail "${label}: SQLite integrity_check FAILED"
    fi
}

# ==============================================================================
# PHASE 1 — Deploy Stack
# ==============================================================================
header "PHASE 1 — Deploy Stack (${TARGET_HOST})"
phase "Running deploy_stack.sh ${TARGET_HOST}..."

if run_script "deploy" "${HOMELAB_DIR}/scripts/deploy_stack.sh" "${TARGET_HOST}"; then
    pass "deploy_stack.sh: exited 0"
else
    fail "deploy_stack.sh: FAILED — aborting (Phase 1 is a hard requirement)"
    # Print summary so far and exit
    log "\n${RED}${BOLD}Aborted at Phase 1. Fix deploy_stack.sh errors and retry.${NC}"
    exit 1
fi

log "  Waiting 20s for containers to stabilise..."
sleep 20

phase "Container status post-deploy"
check_containers "[Phase 1]"

phase "HTTP endpoint spot-checks post-deploy"
http_spot_checks "[Phase 1]"

# ==============================================================================
# PHASE 2 — Full Healthcheck (runs healthcheck.sh verbatim)
# ==============================================================================
header "PHASE 2 — Full Healthcheck (${TARGET_HOST})"
phase "Running healthcheck.sh ${TARGET_HOST}..."

# healthcheck.sh has set -euo pipefail and exits 0 even with warnings
# (it doesn't exit non-zero on warn, only on fail)
HC_EXIT=0
run_script "healthcheck" "${HOMELAB_DIR}/scripts/healthcheck.sh" "${TARGET_HOST}" || HC_EXIT=$?
if [[ "${HC_EXIT}" -eq 0 ]]; then
    pass "healthcheck.sh: all checks passed (exit 0)"
else
    warn "healthcheck.sh: exited ${HC_EXIT} — review log for failures"
fi

# ==============================================================================
# PHASE 3 — Backup & Cloudflare R2 Upload
# ==============================================================================
header "PHASE 3 — Backup & Cloudflare R2 Upload"
phase "Running backup_homelab.sh ${TARGET_HOST}..."

if run_script "backup" "${HOMELAB_DIR}/scripts/backup_homelab.sh" "${TARGET_HOST}"; then
    pass "backup_homelab.sh: exited 0"
else
    fail "backup_homelab.sh: FAILED — aborting (no archive to restore from)"
    exit 1
fi

# Locate the archive just created.
# backup_homelab.sh names archives: homelab_backup_<host>_<YYYYMMDD_HHMMSS>.tar.gz
LATEST_BACKUP=$(ls -t "${HOMELAB_DIR}/data/backups/homelab_backup_${TARGET_HOST}_"*.tar.gz \
                2>/dev/null | head -1 || echo "")
if [[ -n "${LATEST_BACKUP}" && -f "${LATEST_BACKUP}" ]]; then
    BACKUP_SIZE=$(du -sh "${LATEST_BACKUP}" | cut -f1)
    pass "Archive found: $(basename "${LATEST_BACKUP}") (${BACKUP_SIZE})"
else
    fail "No archive matching homelab_backup_${TARGET_HOST}_*.tar.gz found — cannot proceed with DR drill"
    exit 1
fi

# Verify permissions match what backup_homelab.sh sets (0600)
ARCH_PERMS=$(stat -c "%a" "${LATEST_BACKUP}" 2>/dev/null || echo "")
[[ "${ARCH_PERMS}" == "600" ]] && pass "Archive permissions: 0600 (correct)" \
                                || warn "Archive permissions: ${ARCH_PERMS} (expected 0600)"

# Verify Cloudflare R2 upload using the same rclone remote backup_homelab.sh uses
RCLONE_CONF="${HOMELAB_DIR}/data/rclone/rclone.conf"
if command -v rclone &>/dev/null && [[ -f "${RCLONE_CONF}" ]]; then
    log "  Querying Cloudflare R2 (r2-crypt:) for backup files..."
    R2_LIST=$(rclone ls r2-crypt: --config "${RCLONE_CONF}" 2>&1 || echo "")
    echo "${R2_LIST}" >> "${LOG_FILE}"
    R2_COUNT=$(echo "${R2_LIST}" | grep -c "homelab_backup" 2>/dev/null || echo "0")
    if [[ "${R2_COUNT}" -gt 0 ]]; then
        pass "Cloudflare R2: ${R2_COUNT} backup file(s) confirmed in bucket"
    else
        warn "Cloudflare R2: no homelab_backup files found — check rclone config or network"
    fi
else
    warn "rclone or ${RCLONE_CONF} not found — skipping R2 verification"
fi

# ==============================================================================
# PHASE 4 — Disaster Recovery Drill
# ==============================================================================
header "PHASE 4 — Disaster Recovery Drill"

# ── 4a: Stop stack ────────────────────────────────────────────────────────────
phase "Stopping containers (docker compose down)..."
COMPOSE_FILE="${HOMELAB_DIR}/hosts/${TARGET_HOST}/docker-compose.yml"
PROJECT_NAME=$([[ "${TARGET_HOST}" == "dev2" ]] && echo "dev2" || echo "homelab")
docker compose -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" down 2>&1 | tee -a "${LOG_FILE}" || true
pass "Containers stopped"

# ── 4b: Wipe data (simulate disaster) ────────────────────────────────────────
phase "Simulating disaster — wiping data directories and root .env..."

# Wipe dirs that restore_homelab.sh recovers for each host
if [[ "${TARGET_HOST}" == "dev2" ]]; then
    WIPE_DIRS=(
        "${HOMELAB_DIR}/data/dev2/obsidian"
        "${HOMELAB_DIR}/data/dev2/beszel/data"
        "${HOMELAB_DIR}/data/dev2/gatus"
    )
else
    # dev1: wipe Vaultwarden DB and AdGuard config (most critical recoverable assets)
    # We do NOT wipe caddy/obsidian since they are non-critical for the integrity test
    WIPE_DIRS=(
        "${HOMELAB_DIR}/data/vaultwarden"
        "${HOMELAB_DIR}/data/adguard/conf"
    )
fi

for d in "${WIPE_DIRS[@]}"; do
    if [[ -d "${d}" ]]; then
        rm -rf "${d}"
        pass "Wiped: ${d}"
    else
        warn "Directory not present (skipping): ${d}"
    fi
done

# Wipe root .env — dangling symlinks in hosts/dev1 and hosts/dev2 will follow
rm -f "${HOMELAB_DIR}/.env"
pass "Wiped: ${HOMELAB_DIR}/.env (host symlinks now dangling — restore will recreate)"

# ── 4c: Restore ───────────────────────────────────────────────────────────────
# restore_homelab.sh signature: <archive.tar.gz> [--target-dir <dir>]
# Host type is auto-detected from config/host.txt inside the archive.
# No host argument is passed — this mirrors how users would run it in production.
phase "Restoring from: $(basename "${LATEST_BACKUP}")"

if run_script "restore" "${HOMELAB_DIR}/scripts/restore_homelab.sh" "${LATEST_BACKUP}"; then
    pass "restore_homelab.sh: exited 0"
else
    fail "restore_homelab.sh: FAILED — check log: ${LOG_FILE}"
    log "\n${RED}${BOLD}Aborted at Phase 4 restore. Manual recovery needed.${NC}"
    exit 1
fi

# ── 4d: Post-restore .env & symlink verification ─────────────────────────────
phase "Post-restore .env & symlink checks"

# Reload env — it was wiped during the drill
if load_env; then
    pass ".env restored and reloaded (${ENV_FILE})"
else
    fail ".env NOT found at ${ENV_FILE} after restore"
fi

# Verify key email vars survived the restore round-trip
SMTP_V=$(grep '^SMTP_FROM='   "${ENV_FILE}" 2>/dev/null | cut -d= -f2- || echo "")
ALERT_V=$(grep '^ALERT_EMAIL=' "${ENV_FILE}" 2>/dev/null | cut -d= -f2- || echo "")
[[ -n "${SMTP_V}" ]]  && pass "SMTP_FROM present after restore: ${SMTP_V}" \
                      || warn "SMTP_FROM missing from restored .env"
[[ -n "${ALERT_V}" ]] && pass "ALERT_EMAIL present after restore: ${ALERT_V}" \
                       || warn "ALERT_EMAIL missing from restored .env"

# Both symlinks must be recreated regardless of whether dev1 or dev2 archive
# (restore_homelab.sh now creates both in both code paths)
for HOST_ENV in "${HOMELAB_DIR}/hosts/dev1/.env" "${HOMELAB_DIR}/hosts/dev2/.env"; do
    if [[ -L "${HOST_ENV}" ]]; then
        LINK_TARGET=$(readlink "${HOST_ENV}")
        if [[ -f "${HOST_ENV}" ]]; then
            pass "Symlink intact and resolves: ${HOST_ENV} → ${LINK_TARGET}"
        else
            fail "Symlink exists but target missing: ${HOST_ENV} → ${LINK_TARGET}"
        fi
    else
        warn "Not a symlink after restore: ${HOST_ENV}"
    fi
done

# ── 4e: SQLite integrity (mirrors restore_homelab.sh PRAGMA integrity_check) ──
phase "SQLite database integrity verification"
if [[ "${TARGET_HOST}" == "dev1" ]]; then
    check_sqlite "${HOMELAB_DIR}/data/vaultwarden/db.sqlite3" "Vaultwarden"
else
    check_sqlite "${HOMELAB_DIR}/data/dev2/beszel/data/data.db" "Beszel Hub"
    check_sqlite "${HOMELAB_DIR}/data/dev2/gatus/gatus.db"      "Gatus"
fi

# ── 4f: Re-deploy from restored state ────────────────────────────────────────
phase "Re-deploying stack from restored state..."

if run_script "redeploy" "${HOMELAB_DIR}/scripts/deploy_stack.sh" "${TARGET_HOST}"; then
    pass "Re-deploy from restored state: exited 0"
else
    fail "Re-deploy after restore: FAILED"
    exit 1
fi

log "  Waiting 20s for containers to stabilise post-restore..."
sleep 20

# ── 4g: Post-restore container & endpoint verification ───────────────────────
phase "Post-restore container & endpoint verification"
check_containers "[Phase 4]"
http_spot_checks "[Phase 4]"

# ==============================================================================
# FINAL REPORT
# ==============================================================================
header "DR Validation — Final Report"
log "Finished: $(date)"
log ""
log "  ${GREEN}✔ PASS${NC}: ${PASS_COUNT}"
log "  ${YELLOW}⚠ WARN${NC}: ${WARN_COUNT}"
log "  ${RED}✖ FAIL${NC}: ${FAIL_COUNT}"
log ""
log "Full log saved to: ${LOG_FILE}"

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    log "\n${RED}${BOLD}❌ DR VALIDATION FAILED — ${FAIL_COUNT} critical failure(s). Review log above.${NC}"
    exit 1
else
    log "\n${GREEN}${BOLD}✅ DR VALIDATION PASSED — All services restored and verified successfully.${NC}"
    exit 0
fi
