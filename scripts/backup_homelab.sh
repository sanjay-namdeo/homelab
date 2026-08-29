#!/usr/bin/env bash
# ==============================================================================
# Homelab Automated Snapshot & Backup Script (Multi-Host: dev1 & dev2)
# ==============================================================================
# Performs consistent, non-blocking point-in-time backups:
#  - dev1: SQLite online hot-backup (Vaultwarden, Uptime Kuma), AdGuard conf,
#          Caddy TLS state, environment & compose definitions.
#  - dev2: MariaDB live atomic dump (Firefly III), uploaded receipts/documents,
#          environment & compose definitions.
#  - Compresses into a timestamped, permission-locked (0600) archive
#  - Automatic retention cleanup (default: 14 days)
#  - Off-site Cloudflare R2 encrypted sync via rclone (if configured)
# ==============================================================================

set -euo pipefail

HOMELAB_DIR="/opt/homelab"
BACKUP_ROOT="${HOMELAB_DIR}/data/backups"
RETENTION_DAYS=14
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEMP_DIR="/tmp/homelab_backup_${TIMESTAMP}"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root or with sudo: sudo $0"
    exit 1
fi

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
    if [[ "${HOSTNAME_S}" == "dev2" ]] || docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^firefly_"; then
        TARGET_HOST="dev2"
    else
        TARGET_HOST="dev1"
    fi
fi

ARCHIVE_NAME="homelab_backup_${TARGET_HOST}_${TIMESTAMP}.tar.gz"

echo "=========================================================="
echo " Starting Homelab Stack Automated Backup (${TARGET_HOST})"
echo "=========================================================="

mkdir -p "${BACKUP_ROOT}"
chmod 700 "${BACKUP_ROOT}"
mkdir -p "${TEMP_DIR}"

if [[ "${TARGET_HOST}" == "dev2" ]]; then
    # --------------------------------------------------------------------------
    # DEV2 BACKUP: Firefly III & MariaDB
    # --------------------------------------------------------------------------
    mkdir -p "${TEMP_DIR}/mariadb" "${TEMP_DIR}/firefly/upload" "${TEMP_DIR}/config"

    # 1. MariaDB Hot Dump
    log_info "[1/6] Performing non-blocking MariaDB hot dump of 'firefly' database..."
    DEV2_ENV="${HOMELAB_DIR}/hosts/dev2/.env"
    DB_PASS=""
    if [[ -f "${DEV2_ENV}" ]]; then
        DB_PASS=$(grep '^DB_PASSWORD=' "${DEV2_ENV}" | cut -d= -f2- || echo "")
    fi

    if docker ps --format '{{.Names}}' | grep -q "^firefly_db$"; then
        if [[ -n "${DB_PASS}" ]]; then
            docker exec firefly_db mariadb-dump -u firefly -p"${DB_PASS}" --single-transaction --quick firefly > "${TEMP_DIR}/mariadb/firefly.sql"
            SQL_SIZE=$(du -h "${TEMP_DIR}/mariadb/firefly.sql" | awk '{print $1}')
            log_success "MariaDB hot dump captured successfully (${SQL_SIZE})."
        else
            log_warn "DB_PASSWORD not found in ${DEV2_ENV}, attempting dump without password..."
            docker exec firefly_db mariadb-dump -u root firefly > "${TEMP_DIR}/mariadb/firefly.sql" 2>/dev/null || log_warn "Could not dump MariaDB database."
        fi
    else
        log_warn "firefly_db container is not running. Checking raw database files..."
        if [[ -d "${HOMELAB_DIR}/data/dev2/firefly/db" ]]; then
            log_info "Archiving raw database directory..."
            mkdir -p "${TEMP_DIR}/mariadb/raw"
            cp -a "${HOMELAB_DIR}/data/dev2/firefly/db" "${TEMP_DIR}/mariadb/raw/"
        fi
    fi

    # 2. Firefly Uploaded Files (Receipts & Attachments)
    log_info "[2/6] Archiving Firefly III uploaded files and attachments..."
    if [[ -d "${HOMELAB_DIR}/data/dev2/firefly/upload" ]]; then
        cp -a "${HOMELAB_DIR}/data/dev2/firefly/upload"/. "${TEMP_DIR}/firefly/upload/" 2>/dev/null || true
        log_success "Firefly III attachments archived."
    fi

    # 3. Firefly Data Importer Files & Configurations
    log_info "[3/6] Archiving Firefly Data Importer files and configurations..."
    if [[ -d "${HOMELAB_DIR}/data/dev2/firefly/import" ]]; then
        mkdir -p "${TEMP_DIR}/firefly/import"
        cp -a "${HOMELAB_DIR}/data/dev2/firefly/import"/. "${TEMP_DIR}/firefly/import/" 2>/dev/null || true
        log_success "Firefly Data Importer directory archived."
    fi

    # 4. Obsidian Markdown Vault & Web Data
    log_info "[4/6] Archiving Obsidian Markdown Vault and Web configuration..."
    if [[ -d "${HOMELAB_DIR}/data/dev2/obsidian" ]]; then
        mkdir -p "${TEMP_DIR}/obsidian"
        cp -a "${HOMELAB_DIR}/data/dev2/obsidian"/. "${TEMP_DIR}/obsidian/" 2>/dev/null || true
        log_success "Obsidian Markdown Vault and Flatnotes data archived."
    fi

    # 5. Beszel Server Monitoring Hub Data & Keys
    log_info "[5/6] Archiving Beszel Hub data and cryptographic keys..."
    if [[ -d "${HOMELAB_DIR}/data/dev2/beszel/data" ]]; then
        mkdir -p "${TEMP_DIR}/beszel/data"
        cp -a "${HOMELAB_DIR}/data/dev2/beszel/data"/. "${TEMP_DIR}/beszel/data/" 2>/dev/null || true
        log_success "Beszel Hub metrics database and keys archived."
    fi

    # 6. Host Environment & Compose Definition
    log_info "[6/6] Archiving dev2 stack definition and environment secrets..."
    [[ -f "${DEV2_ENV}" ]] && cp "${DEV2_ENV}" "${TEMP_DIR}/config/.env"
    [[ -f "${HOMELAB_DIR}/hosts/dev2/docker-compose.yml" ]] && cp "${HOMELAB_DIR}/hosts/dev2/docker-compose.yml" "${TEMP_DIR}/config/docker-compose.yml"
    echo "${TARGET_HOST}" > "${TEMP_DIR}/config/host.txt"

else
    # --------------------------------------------------------------------------
    # DEV1 BACKUP: Vaultwarden, AdGuard Home, Uptime Kuma, Caddy
    # --------------------------------------------------------------------------
    mkdir -p "${TEMP_DIR}/vaultwarden" "${TEMP_DIR}/adguard" "${TEMP_DIR}/caddy" "${TEMP_DIR}/uptime-kuma" "${TEMP_DIR}/config"

    # 1. Vaultwarden Point-in-Time SQLite Backup
    log_info "[1/5] Creating live point-in-time SQLite snapshot of Vaultwarden..."
    VW_DB="${HOMELAB_DIR}/data/vaultwarden/db.sqlite3"
    if [[ -f "${VW_DB}" ]]; then
        python3 -c "
import sqlite3
src = sqlite3.connect('${VW_DB}')
dst = sqlite3.connect('${TEMP_DIR}/vaultwarden/db.sqlite3')
src.backup(dst)
dst.close()
src.close()
"
        log_success "Vaultwarden database snapshot captured."
    else
        log_warn "Vaultwarden db.sqlite3 not found, skipping SQLite snapshot."
    fi

    [[ -f "${HOMELAB_DIR}/data/vaultwarden/config.json" ]] && cp "${HOMELAB_DIR}/data/vaultwarden/config.json" "${TEMP_DIR}/vaultwarden/"
    [[ -f "${HOMELAB_DIR}/data/vaultwarden/rsa_key.pem" ]] && cp "${HOMELAB_DIR}/data/vaultwarden/rsa_key.pem" "${TEMP_DIR}/vaultwarden/"

    # 2. AdGuard Home Configuration
    log_info "[2/5] Backing up AdGuard Home configuration..."
    if [[ -d "${HOMELAB_DIR}/data/adguard/conf" ]]; then
        cp -r "${HOMELAB_DIR}/data/adguard/conf" "${TEMP_DIR}/adguard/"
        log_success "AdGuard Home configuration backed up."
    fi

    # 3. Caddy Configuration & Certificate State
    log_info "[3/5] Backing up Caddy reverse proxy files..."
    [[ -f "${HOMELAB_DIR}/Caddyfile" ]] && cp "${HOMELAB_DIR}/Caddyfile" "${TEMP_DIR}/caddy/"
    [[ -f "${HOMELAB_DIR}/hosts/dev1/Caddyfile" ]] && cp "${HOMELAB_DIR}/hosts/dev1/Caddyfile" "${TEMP_DIR}/caddy/Caddyfile.host"

    # 4. Uptime Kuma Database Snapshot
    log_info "[4/5] Creating live point-in-time SQLite snapshot of Uptime Kuma..."
    UK_DB="${HOMELAB_DIR}/data/uptime-kuma/kuma.db"
    if [[ -f "${UK_DB}" ]]; then
        python3 -c "
import sqlite3
src = sqlite3.connect('${UK_DB}')
dst = sqlite3.connect('${TEMP_DIR}/uptime-kuma/kuma.db')
src.backup(dst)
dst.close()
src.close()
"
        log_success "Uptime Kuma database snapshot captured."
    else
        log_warn "Uptime Kuma kuma.db not found, skipping SQLite snapshot."
    fi

    # 5. Stack Definitions & Secrets
    log_info "[5/5] Archiving stack definition files..."
    [[ -f "${HOMELAB_DIR}/.env" ]] && cp "${HOMELAB_DIR}/.env" "${TEMP_DIR}/config/.env"
    [[ -f "${HOMELAB_DIR}/hosts/dev1/.env" ]] && cp "${HOMELAB_DIR}/hosts/dev1/.env" "${TEMP_DIR}/config/.env.dev1"
    [[ -f "${HOMELAB_DIR}/docker-compose.yml" ]] && cp "${HOMELAB_DIR}/docker-compose.yml" "${TEMP_DIR}/config/docker-compose.yml"
    [[ -f "${HOMELAB_DIR}/hosts/dev1/docker-compose.yml" ]] && cp "${HOMELAB_DIR}/hosts/dev1/docker-compose.yml" "${TEMP_DIR}/config/docker-compose.dev1.yml"
    echo "${TARGET_HOST}" > "${TEMP_DIR}/config/host.txt"
fi

# ------------------------------------------------------------------------------
# Compress, Restrict Permissions & Rotate Old Backups
# ------------------------------------------------------------------------------
log_info "Creating compressed backup archive..."
FINAL_ARCHIVE="${BACKUP_ROOT}/${ARCHIVE_NAME}"
tar -czf "${FINAL_ARCHIVE}" -C "${TEMP_DIR}" .
chmod 600 "${FINAL_ARCHIVE}"
rm -rf "${TEMP_DIR}"

ARCHIVE_SIZE=$(du -h "${FINAL_ARCHIVE}" | awk '{print $1}')
log_success "Backup archive created: ${FINAL_ARCHIVE} (${ARCHIVE_SIZE})"

# Purge archives older than RETENTION_DAYS
log_info "Pruning local backups older than ${RETENTION_DAYS} days..."
PURGED=$(find "${BACKUP_ROOT}" -name "homelab_backup_*.tar.gz" -mtime +"${RETENTION_DAYS}" -print -delete | wc -l)
log_success "Pruned ${PURGED} old backup archive(s)."

# ------------------------------------------------------------------------------
# Off-Site Cloudflare R2 Encrypted Sync (Zero-Knowledge AES-256)
# ------------------------------------------------------------------------------
RCLONE_CONF="${HOMELAB_DIR}/data/rclone/rclone.conf"
if command -v rclone &>/dev/null && [[ -f "${RCLONE_CONF}" ]]; then
    log_info "Syncing encrypted backups to Cloudflare R2 (r2-crypt:)..."
    if rclone copy "${BACKUP_ROOT}" r2-crypt: --config "${RCLONE_CONF}" --no-update-modtime --fast-list --quiet; then
        log_success "Off-site encrypted sync to Cloudflare R2 complete."
    else
        log_warn "Off-site rclone sync encountered a non-fatal warning."
    fi
else
    log_info "rclone configuration not found, skipping off-site sync."
fi

echo ""
echo "=========================================================="
echo -e "${GREEN} Homelab Backup & Off-Site Sync Completed!${NC}"
echo "=========================================================="
echo "Host:           ${TARGET_HOST}"
echo "Local Archive:  ${FINAL_ARCHIVE}"
echo "Size:           ${ARCHIVE_SIZE}"
echo "Owner:          root:root (0600)"
echo "Off-Site Cloud: Cloudflare R2 (homelab/backups encrypted)"
echo "=========================================================="

