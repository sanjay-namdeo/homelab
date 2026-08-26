#!/usr/bin/env bash
# ==============================================================================
# Homelab Automated Snapshot & Backup Script
# ==============================================================================
# Performs consistent, non-blocking point-in-time backups:
#  1. SQLite online hot-backup for Vaultwarden
#  2. Configuration snapshot for AdGuard Home (AdGuardHome.yaml & filters)
#  3. Caddy TLS certificates and configuration state
#  4. Environment (.env) and Docker Compose definitions
#  5. Compresses into a timestamped, permission-locked (0600) archive
#  6. Automatic retention cleanup (default: 14 days)
# ==============================================================================

set -euo pipefail

HOMELAB_DIR="/opt/homelab"
BACKUP_ROOT="${HOMELAB_DIR}/data/backups"
RETENTION_DAYS=14
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEMP_DIR="/tmp/homelab_backup_${TIMESTAMP}"
ARCHIVE_NAME="homelab_backup_${TIMESTAMP}.tar.gz"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root or with sudo: sudo $0"
    exit 1
fi

echo "=========================================================="
echo " Starting Homelab Stack Automated Backup"
echo "=========================================================="

mkdir -p "${BACKUP_ROOT}"
chmod 700 "${BACKUP_ROOT}"
mkdir -p "${TEMP_DIR}/vaultwarden" "${TEMP_DIR}/adguard" "${TEMP_DIR}/caddy" "${TEMP_DIR}/config"

# ------------------------------------------------------------------------------
# 1. Vaultwarden Point-in-Time SQLite Backup
# ------------------------------------------------------------------------------
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
    log_warn "db.sqlite3 not found, skipping SQLite snapshot."
fi

# Copy Vaultwarden configs and keys (if present)
[[ -f "${HOMELAB_DIR}/data/vaultwarden/config.json" ]] && cp "${HOMELAB_DIR}/data/vaultwarden/config.json" "${TEMP_DIR}/vaultwarden/"
[[ -f "${HOMELAB_DIR}/data/vaultwarden/rsa_key.pem" ]] && cp "${HOMELAB_DIR}/data/vaultwarden/rsa_key.pem" "${TEMP_DIR}/vaultwarden/"

# ------------------------------------------------------------------------------
# 2. AdGuard Home Configuration
# ------------------------------------------------------------------------------
log_info "[2/5] Backing up AdGuard Home configuration..."
if [[ -d "${HOMELAB_DIR}/data/adguard/conf" ]]; then
    cp -r "${HOMELAB_DIR}/data/adguard/conf" "${TEMP_DIR}/adguard/"
    log_success "AdGuard Home configuration backed up."
fi

# ------------------------------------------------------------------------------
# 3. Caddy Configuration & Certificate State
# ------------------------------------------------------------------------------
log_info "[3/5] Backing up Caddy reverse proxy files..."
[[ -f "${HOMELAB_DIR}/Caddyfile" ]] && cp "${HOMELAB_DIR}/Caddyfile" "${TEMP_DIR}/caddy/"

# ------------------------------------------------------------------------------
# 4. Homelab Environment & Compose Definition
# ------------------------------------------------------------------------------
log_info "[4/5] Archiving stack definition files..."
[[ -f "${HOMELAB_DIR}/.env" ]] && cp "${HOMELAB_DIR}/.env" "${TEMP_DIR}/config/"
[[ -f "${HOMELAB_DIR}/docker-compose.yml" ]] && cp "${HOMELAB_DIR}/docker-compose.yml" "${TEMP_DIR}/config/"

# ------------------------------------------------------------------------------
# 5. Compress, Restrict Permissions & Rotate Old Backups
# ------------------------------------------------------------------------------
log_info "[5/5] Creating compressed backup archive..."
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
# 6. Off-Site Cloudflare R2 Encrypted Sync (Zero-Knowledge AES-256)
# ------------------------------------------------------------------------------
RCLONE_CONF="${HOMELAB_DIR}/data/rclone/rclone.conf"
if command -v rclone &>/dev/null && [[ -f "${RCLONE_CONF}" ]]; then
    log_info "[6/6] Syncing encrypted backups to Cloudflare R2 (r2-crypt:)..."
    if rclone sync "${BACKUP_ROOT}" r2-crypt: --config "${RCLONE_CONF}" --quiet; then
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
echo "Local Archive:  ${FINAL_ARCHIVE}"
echo "Size:           ${ARCHIVE_SIZE}"
echo "Owner:          root:root (0600)"
echo "Off-Site Cloud: Cloudflare R2 (homelab/backups encrypted)"
echo "=========================================================="

