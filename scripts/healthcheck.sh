#!/usr/bin/env bash
# ==============================================================================
# Homelab Stack Health & Security Diagnostic Tool (Multi-Host: dev1 & dev2)
# ==============================================================================
# Performs end-to-end operational, security, and resource checks for homelab nodes.
# ==============================================================================

set -euo pipefail

HOMELAB_DIR="/opt/homelab"
cd "${HOMELAB_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { echo -e "  [${GREEN}✔ PASS${NC}] $1"; }
warn() { echo -e "  [${YELLOW}⚠ WARN${NC}] $1"; }
fail() { echo -e "  [${RED}✖ FAIL${NC}] $1"; }
header() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

# Detect or specify target host
TARGET_HOST=""
if [[ $# -gt 0 ]]; then
    case "$1" in
        --host|-h)
            TARGET_HOST="$2"
            shift 2
            ;;
        dev1|dev2)
            TARGET_HOST="$1"
            shift 1
            ;;
    esac
fi

if [[ -z "${TARGET_HOST}" ]]; then
    HOSTNAME_S=$(hostname -s 2>/dev/null || echo "")
    if [[ "${HOSTNAME_S}" == "dev2" ]] || docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^beszel$"; then
        TARGET_HOST="dev2"
    else
        TARGET_HOST="dev1"
    fi
fi

echo "=========================================================="
echo " Starting Homelab Stack Health & Diagnostic Check (${TARGET_HOST})"
echo "=========================================================="

# ------------------------------------------------------------------------------
# 1. Tailscale Status
# ------------------------------------------------------------------------------
header "1. Tailscale Network Mesh"
TS_IP="127.0.0.1"
TS_FQDN=""
if command -v tailscale &>/dev/null; then
    TS_STATUS=$(tailscale status --json 2>/dev/null || echo "{}")
    TS_RUNNING=$(echo "${TS_STATUS}" | jq -r '.BackendState // empty')
    
    if [[ "${TS_RUNNING}" == "Running" ]]; then
        TS_IP=$(tailscale ip -4 2>/dev/null || echo "Unknown")
        TS_FQDN=$(echo "${TS_STATUS}" | jq -r '.Self.DNSName // empty' | sed 's/\.$//')
        pass "Tailscale is connected and active"
        echo "      Node IP  : ${TS_IP}"
        echo "      Tailnet  : ${TS_FQDN}"
    else
        fail "Tailscale is not connected (State: ${TS_RUNNING})"
    fi
else
    fail "Tailscale CLI is not installed"
fi

if [[ "${TARGET_HOST}" == "dev2" ]]; then
    # ==========================================================================
    # DEV2 DIAGNOSTIC SUITE (Obsidian & Beszel Monitoring Hub)
    # ==========================================================================

    DEV2_ENV="${HOMELAB_DIR}/hosts/dev2/.env"

    # 2. Container Service Health
    header "2. Container Service Health"
    CONTAINERS=("obsidian_web" "beszel" "beszel_agent" "gatus")
    for c in "${CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${c}$"; then
            STATUS=$(docker inspect --format='{{.State.Status}}' "${c}" 2>/dev/null || echo "unknown")
            HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${c}" 2>/dev/null || echo "none")
            if [[ "${HEALTH}" != "none" ]]; then
                pass "Container '${c}' is running (${STATUS}, health: ${HEALTH})"
            else
                pass "Container '${c}' is running (${STATUS})"
            fi
        else
            fail "Container '${c}' is NOT running"
        fi
    done

    # 3. Tailscale Serve Status & Endpoints
    header "3. Functional & Endpoint Verification"
    if command -v tailscale &>/dev/null; then
        SERVE_STATUS=$(tailscale serve status 2>&1 || echo "")
        if echo "${SERVE_STATUS}" | grep -q "127.0.0.1:8083"; then
            pass "Tailscale Serve TLS reverse proxy is active (8083 -> 127.0.0.1:8083 Flatnotes)"
        else
            warn "Tailscale Serve proxying is not active or not targeting 127.0.0.1:8083"
        fi

        if echo "${SERVE_STATUS}" | grep -q "127.0.0.1:8085"; then
            pass "Tailscale Serve TLS reverse proxy is active (8085 -> 127.0.0.1:8085 Gatus)"
        else
            warn "Tailscale Serve proxying is not active or not targeting 127.0.0.1:8085"
        fi

        if echo "${SERVE_STATUS}" | grep -q "127.0.0.1:8090"; then
            pass "Tailscale Serve TLS reverse proxy is active (8090 -> 127.0.0.1:8090 Beszel Hub)"
        else
            warn "Tailscale Serve proxying is not active or not targeting 127.0.0.1:8090"
        fi
    fi

    # Obsidian Flatnotes local endpoint
    FLAT_HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8083/" 2>/dev/null || echo "000")
    if [[ "${FLAT_HTTP}" == "200" || "${FLAT_HTTP}" == "302" ]]; then
        pass "Obsidian Flatnotes Web UI local HTTP endpoint is responding (http://127.0.0.1:8083/ -> HTTP ${FLAT_HTTP})"
    else
        warn "Obsidian Flatnotes Web UI local endpoint returned status code ${FLAT_HTTP}"
    fi

    # Gatus Status Dashboard local endpoint
    GATUS_HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8085/" 2>/dev/null || echo "000")
    if [[ "${GATUS_HTTP}" == "200" || "${GATUS_HTTP}" == "302" ]]; then
        pass "Gatus Health & Status Hub local HTTP endpoint is responding (http://127.0.0.1:8085/ -> HTTP ${GATUS_HTTP})"
    else
        warn "Gatus Hub local endpoint returned status code ${GATUS_HTTP}"
    fi

    # Beszel Hub local endpoint
    BESZEL_HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/" 2>/dev/null || echo "000")
    if [[ "${BESZEL_HTTP}" == "200" || "${BESZEL_HTTP}" == "302" ]]; then
        pass "Beszel Server Health Hub local HTTP endpoint is responding (http://127.0.0.1:8090/ -> HTTP ${BESZEL_HTTP})"
    else
        warn "Beszel Hub local endpoint returned status code ${BESZEL_HTTP}"
    fi

    # HTTPS via Tailscale FQDN
    if [[ -n "${TS_FQDN}" ]]; then
        FLAT_TLS=$(curl -s -k -o /dev/null -w "%{http_code}" "https://${TS_FQDN}:8083/" 2>/dev/null || echo "000")
        if [[ "${FLAT_TLS}" == "200" || "${FLAT_TLS}" == "302" ]]; then
            pass "Obsidian Flatnotes Web UI HTTPS endpoint is responding (https://${TS_FQDN}:8083/ -> HTTP ${FLAT_TLS})"
        else
            warn "Obsidian Flatnotes Web UI HTTPS endpoint returned status code ${FLAT_TLS}"
        fi

        GATUS_TLS=$(curl -s -k -o /dev/null -w "%{http_code}" "https://${TS_FQDN}:8085/" 2>/dev/null || echo "000")
        if [[ "${GATUS_TLS}" == "200" || "${GATUS_TLS}" == "302" ]]; then
            pass "Gatus Health & Status Hub HTTPS endpoint is responding (https://${TS_FQDN}:8085/ -> HTTP ${GATUS_TLS})"
        else
            warn "Gatus Hub HTTPS endpoint returned status code ${GATUS_TLS}"
        fi

        BESZEL_TLS=$(curl -s -k -o /dev/null -w "%{http_code}" "https://${TS_FQDN}:8090/" 2>/dev/null || echo "000")
        if [[ "${BESZEL_TLS}" == "200" || "${BESZEL_TLS}" == "302" ]]; then
            pass "Beszel Server Health Hub HTTPS endpoint is responding (https://${TS_FQDN}:8090/ -> HTTP ${BESZEL_TLS})"
        else
            warn "Beszel Hub HTTPS endpoint returned status code ${BESZEL_TLS}"
        fi
    fi

    # 4. Security & Isolation State
    header "4. Security & Isolation State"
    LAN_IP=$(ip -4 addr show ens3 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 || echo "")
    if [[ -n "${LAN_IP}" ]]; then
        if ! nc -z -w 1 "${LAN_IP}" 8082 2>/dev/null; then
            pass "Port 8082 (Obsidian WebDAV) is closed on WAN/LAN interface (${LAN_IP}) - Secure"
        else
            fail "Port 8082 is accessible on WAN/LAN interface (${LAN_IP})!"
        fi

        if ! nc -z -w 1 "${LAN_IP}" 8083 2>/dev/null; then
            pass "Port 8083 (Obsidian Flatnotes Web UI) is closed on WAN/LAN interface (${LAN_IP}) - Secure"
        else
            fail "Port 8083 is accessible on WAN/LAN interface (${LAN_IP})!"
        fi

        if ! nc -z -w 1 "${LAN_IP}" 8085 2>/dev/null; then
            pass "Port 8085 (Gatus Status Hub) is closed on WAN/LAN interface (${LAN_IP}) - Secure"
        else
            fail "Port 8085 is accessible on WAN/LAN interface (${LAN_IP})!"
        fi

        if ! nc -z -w 1 "${LAN_IP}" 8090 2>/dev/null; then
            pass "Port 8090 (Beszel Hub) is closed on WAN/LAN interface (${LAN_IP}) - Secure"
        else
            fail "Port 8090 is accessible on WAN/LAN interface (${LAN_IP})!"
        fi
    fi

    if [[ -f "${DEV2_ENV}" ]]; then
        ENV_PERMS=$(stat -c "%a" "${DEV2_ENV}" 2>/dev/null || echo "")
        if [[ "${ENV_PERMS}" == "600" ]]; then
            pass "dev2 .env secret permissions are strictly locked (0600)"
        else
            warn "dev2 .env secret permissions: ${ENV_PERMS} (recommended: 0600)"
        fi
    fi

else
    # ==========================================================================
    # DEV1 DIAGNOSTIC SUITE (Vaultwarden, AdGuard, Obsidian WebDAV, Caddy, Beszel Agent)
    # ==========================================================================

    # 2. Container Service Health
    header "2. Container Service Health"
    CONTAINERS=("vaultwarden" "adguardhome" "caddy" "obsidian_webdav" "beszel_agent")
    for c in "${CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${c}$"; then
            STATUS=$(docker inspect --format='{{.State.Status}}' "${c}" 2>/dev/null || echo "unknown")
            HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${c}" 2>/dev/null || echo "none")
            if [[ "${HEALTH}" != "none" ]]; then
                pass "Container '${c}' is running (${STATUS}, health: ${HEALTH})"
            else
                pass "Container '${c}' is running (${STATUS})"
            fi
        else
            fail "Container '${c}' is NOT running"
        fi
    done

    # 3. Functional & Endpoint Verification
    header "3. Functional & Endpoint Verification"

    # Vaultwarden HTTPS
    if [[ -n "${TS_FQDN}" ]]; then
        HTTP_CODE=$(curl -s -k -o /dev/null -w "%{http_code}" "https://${TS_FQDN}/alive" 2>/dev/null || echo "000")
        if [[ "${HTTP_CODE}" == "200" ]]; then
            pass "Vaultwarden HTTPS is responding (https://${TS_FQDN} -> HTTP 200 OK)"
        else
            warn "Vaultwarden HTTPS returned status code ${HTTP_CODE}"
        fi
    fi

    # AdGuard Home DNS
    if dig @"${TS_IP}" google.com +short +time=2 &>/dev/null; then
        pass "AdGuard Home DNS is resolving queries via Tailscale IP (${TS_IP}:53)"
    else
        fail "AdGuard Home DNS resolution failed on ${TS_IP}:53"
    fi

    # AdGuard Home Web UI (HTTPS / HTTP)
    if [[ -n "${TS_FQDN}" ]]; then
        AG_HTTP=$(curl -s -k -o /dev/null -w "%{http_code}" "https://${TS_FQDN}:8081/login.html" 2>/dev/null || echo "000")
        if [[ "${AG_HTTP}" == "200" ]]; then
            pass "AdGuard Home Web UI HTTPS is responding (https://${TS_FQDN}:8081 -> HTTP 200 OK)"
        else
            warn "AdGuard Home Web UI HTTPS returned status code ${AG_HTTP}"
        fi
    else
        AG_HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://${TS_IP}:8081/login.html" 2>/dev/null || echo "000")
        if [[ "${AG_HTTP}" == "200" ]]; then
            pass "AdGuard Home Web UI is reachable (http://${TS_IP}:8081 -> HTTP 200 OK)"
        else
            warn "AdGuard Home Web UI returned status code ${AG_HTTP}"
        fi
    fi

    # Obsidian WebDAV Sync (HTTPS / HTTP)
    DEV1_ENV="${HOMELAB_DIR}/hosts/dev1/.env"
    DAV_USER="obsidian"
    DAV_PASS=""
    [[ -f "${DEV1_ENV}" ]] && DAV_PASS=$(grep '^WEBDAV_PASSWORD=' "${DEV1_ENV}" | cut -d= -f2- || echo "")
    [[ -z "${DAV_PASS}" && -f "${HOMELAB_DIR}/.env" ]] && DAV_PASS=$(grep '^WEBDAV_PASSWORD=' "${HOMELAB_DIR}/.env" | cut -d= -f2- || echo "")

    if [[ -n "${TS_FQDN}" ]]; then
        DAV_TLS=$(curl -s -k -u "${DAV_USER}:${DAV_PASS}" -o /dev/null -w "%{http_code}" "https://${TS_FQDN}:8082/data/" 2>/dev/null || echo "000")
        if [[ "${DAV_TLS}" == "200" || "${DAV_TLS}" == "207" || "${DAV_TLS}" == "301" ]]; then
            pass "Obsidian WebDAV HTTPS is responding (https://${TS_FQDN}:8082/data/ -> HTTP ${DAV_TLS})"
        else
            warn "Obsidian WebDAV HTTPS returned status code ${DAV_TLS}"
        fi
    fi

    # Caddy HTTP Redirect
    CADDY_REDIR=$(curl -s -I "http://127.0.0.1/" 2>/dev/null | grep -i "Location:" || echo "")
    if [[ "${CADDY_REDIR}" =~ "https://" ]]; then
        pass "Caddy HTTP-to-HTTPS redirect is active (${CADDY_REDIR//[$'\t\r\n']/})"
    else
        warn "Caddy redirect check did not return expected HTTPS location header"
    fi

    # 4. Security & Network Isolation Checks
    header "4. Security & Isolation State"
    LAN_IP=$(ip -4 addr show ens3 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 || echo "")
    if [[ -n "${LAN_IP}" ]]; then
        if ! nc -z -w 1 "${LAN_IP}" 8081 2>/dev/null; then
            pass "Port 8081 (AdGuard Web) is closed on WAN/LAN interface (${LAN_IP}) - Secure"
        else
            fail "Port 8081 is accessible on WAN/LAN interface (${LAN_IP})!"
        fi

        if ! nc -z -w 1 "${LAN_IP}" 8082 2>/dev/null; then
            pass "Port 8082 (Obsidian WebDAV) is closed on WAN/LAN interface (${LAN_IP}) - Secure"
        else
            fail "Port 8082 is accessible on WAN/LAN interface (${LAN_IP})!"
        fi

        if ! nc -z -w 1 "${LAN_IP}" 53 2>/dev/null; then
            pass "Port 53 is closed on WAN/LAN interface (${LAN_IP}) - Secure"
        else
            fail "Port 53 is accessible on WAN/LAN interface (${LAN_IP})!"
        fi
    fi

    VW_PERMS=$(stat -c "%a" "${HOMELAB_DIR}/data/vaultwarden" 2>/dev/null || echo "")
    if [[ "${VW_PERMS}" == "700" ]]; then
        pass "Vaultwarden data directory permissions are strictly locked (0700)"
    elif [[ -n "${VW_PERMS}" ]]; then
        warn "Vaultwarden data directory permissions: ${VW_PERMS} (recommended: 0700)"
    fi
fi

# ------------------------------------------------------------------------------
# 5. Backup & Off-Site Cloudflare R2 Sync Verification
# ------------------------------------------------------------------------------
header "5. Backup & Off-Site Disaster Recovery"
LATEST_BACKUP=$(ls -t "${HOMELAB_DIR}/data/backups/homelab_backup_${TARGET_HOST}_"*.tar.gz 2>/dev/null | head -n 1 || echo "")
if [[ -n "${LATEST_BACKUP}" && -f "${LATEST_BACKUP}" ]]; then
    BACKUP_FILE=$(basename "${LATEST_BACKUP}")
    BACKUP_SIZE=$(du -h "${LATEST_BACKUP}" | awk '{print $1}')
    BACKUP_DATE=$(stat -c "%y" "${LATEST_BACKUP}" 2>/dev/null | cut -d. -f1 || echo "")
    pass "Latest local backup exists: ${BACKUP_FILE} (${BACKUP_SIZE}, ${BACKUP_DATE})"
else
    warn "No local backup found in ${HOMELAB_DIR}/data/backups for host '${TARGET_HOST}'"
fi

RCLONE_CONF="${HOMELAB_DIR}/data/rclone/rclone.conf"
if [[ -f "${RCLONE_CONF}" ]]; then
    RCLONE_PERMS=$(stat -c "%a" "${RCLONE_CONF}" 2>/dev/null || echo "")
    if [[ "${RCLONE_PERMS}" == "600" ]]; then
        pass "Cloudflare R2 rclone configuration is present and secured (0600)"
    else
        warn "Cloudflare R2 rclone configuration permissions: ${RCLONE_PERMS} (recommended: 0600)"
    fi
else
    warn "Cloudflare R2 rclone configuration not found (${RCLONE_CONF})"
fi

# Check systemd timer or cron
if systemctl is-active --quiet homelab-backup.timer 2>/dev/null; then
    NEXT_RUN=$(systemctl list-timers homelab-backup.timer --no-legend 2>/dev/null | awk '{print $1" "$2" "$3}' || echo "")
    pass "Automated daily backup timer is active (Next scheduled: ${NEXT_RUN})"
elif crontab -l 2>/dev/null | grep -q "backup_homelab.sh"; then
    pass "Automated backup cron job is configured in crontab"
else
    warn "No automated backup timer (homelab-backup.timer) or cron job detected"
fi

# ------------------------------------------------------------------------------
# 6. Host Resource Consumption
# ------------------------------------------------------------------------------
header "6. System Resource Utilization"
RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')
RAM_USED=$(free -h | awk '/Mem:/ {print $3}')
SWAP_TOTAL=$(free -h | awk '/Swap:/ {print $2}')
SWAP_USED=$(free -h | awk '/Swap:/ {print $3}')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
DISK_USE=$(df -h / | awk 'NR==2 {print $5}')

echo "  Memory : ${RAM_USED} used / ${RAM_TOTAL} total"
echo "  Swap   : ${SWAP_USED} used / ${SWAP_TOTAL} total"
echo "  Disk   : ${DISK_USE} used (${DISK_AVAIL} available)"

echo ""
echo "=========================================================="
echo -e "${GREEN} Diagnostic Check Complete!${NC}"
echo "=========================================================="

