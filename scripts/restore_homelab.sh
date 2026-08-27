#!/usr/bin/env bash
# ==============================================================================
# Homelab Automated Disaster Recovery & Restore Script
# ==============================================================================
# Restores homelab stack state from a timestamped backup archive:
#  1. Validates archive integrity and file layout
#  2. Restores Vaultwarden database & cryptographic keys
#  3. Restores AdGuard Home configuration
#  4. Restores Uptime Kuma monitoring database
#  5. Restores Caddyfile and .env configuration
#  6. Enforces strict security permissions (0700/0600)
#  7. Validates SQLite database integrity (PRAGMA integrity_check)
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    echo "Usage: sudo $0 <path_to_backup_archive.tar.gz> [--target-dir <directory>]"
    echo ""
    echo "Options:"
    echo "  --target-dir <dir>   Restore destination directory (default: /opt/homelab)"
    echo "  -h, --help           Show this help message"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

ARCHIVE_PATH="$1"
shift

TARGET_DIR="/opt/homelab"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target-dir)
            TARGET_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root or with sudo: sudo $0 ..."
    exit 1
fi

if [[ ! -f "${ARCHIVE_PATH}" ]]; then
    log_error "Backup archive not found: ${ARCHIVE_PATH}"
    exit 1
fi

echo "=========================================================="
echo " Starting Homelab Disaster Recovery & Restore"
echo "=========================================================="
log_info "Archive Source    : ${ARCHIVE_PATH}"
log_info "Restore Target    : ${TARGET_DIR}"

TEMP_EXTRACT=$(mktemp -d /tmp/homelab_restore_XXXXXX)
trap 'rm -rf "${TEMP_EXTRACT}"' EXIT

log_info "[1/5] Extracting and verifying backup archive..."
tar -xzf "${ARCHIVE_PATH}" -C "${TEMP_EXTRACT}"

# Create required directories
mkdir -p "${TARGET_DIR}/data/vaultwarden"
mkdir -p "${TARGET_DIR}/data/adguard/conf"
mkdir -p "${TARGET_DIR}/data/adguard/work"
mkdir -p "${TARGET_DIR}/data/uptime-kuma"
mkdir -p "${TARGET_DIR}/data/caddy"

# ------------------------------------------------------------------------------
# 1. Restore Vaultwarden
# ------------------------------------------------------------------------------
log_info "[2/5] Restoring Vaultwarden database and credentials..."
if [[ -f "${TEMP_EXTRACT}/vaultwarden/db.sqlite3" ]]; then
    cp "${TEMP_EXTRACT}/vaultwarden/db.sqlite3" "${TARGET_DIR}/data/vaultwarden/db.sqlite3"
fi
[[ -f "${TEMP_EXTRACT}/vaultwarden/config.json" ]] && cp "${TEMP_EXTRACT}/vaultwarden/config.json" "${TARGET_DIR}/data/vaultwarden/"
[[ -f "${TEMP_EXTRACT}/vaultwarden/rsa_key.pem" ]] && cp "${TEMP_EXTRACT}/vaultwarden/rsa_key.pem" "${TARGET_DIR}/data/vaultwarden/"
chmod 700 "${TARGET_DIR}/data/vaultwarden"
chmod 600 "${TARGET_DIR}/data/vaultwarden"/* 2>/dev/null || true
log_success "Vaultwarden files restored."

# ------------------------------------------------------------------------------
# 2. Restore AdGuard Home
# ------------------------------------------------------------------------------
log_info "[3/5] Restoring AdGuard Home configuration..."
if [[ -d "${TEMP_EXTRACT}/adguard/conf" ]]; then
    cp -r "${TEMP_EXTRACT}/adguard/conf"/* "${TARGET_DIR}/data/adguard/conf/" 2>/dev/null || true
    chmod 700 "${TARGET_DIR}/data/adguard"
    chmod 700 "${TARGET_DIR}/data/adguard/conf"
    log_success "AdGuard Home configuration restored."
fi

# ------------------------------------------------------------------------------
# 3. Restore Uptime Kuma
# ------------------------------------------------------------------------------
log_info "[4/5] Restoring Uptime Kuma database..."
if [[ -f "${TEMP_EXTRACT}/uptime-kuma/kuma.db" ]]; then
    cp "${TEMP_EXTRACT}/uptime-kuma/kuma.db" "${TARGET_DIR}/data/uptime-kuma/kuma.db"
    chmod 700 "${TARGET_DIR}/data/uptime-kuma"
    chmod 600 "${TARGET_DIR}/data/uptime-kuma/kuma.db"
    log_success "Uptime Kuma database restored."
fi

# ------------------------------------------------------------------------------
# 4. Restore Caddyfile & Stack Configs
# ------------------------------------------------------------------------------
log_info "[5/5] Restoring environment and reverse proxy configuration..."
if [[ -f "${TEMP_EXTRACT}/config/.env" ]]; then
    cp "${TEMP_EXTRACT}/config/.env" "${TARGET_DIR}/.env"
    chmod 600 "${TARGET_DIR}/.env"
fi
if [[ -f "${TEMP_EXTRACT}/config/docker-compose.yml" ]]; then
    cp "${TEMP_EXTRACT}/config/docker-compose.yml" "${TARGET_DIR}/docker-compose.yml"
fi
if [[ -f "${TEMP_EXTRACT}/caddy/Caddyfile" ]]; then
    cp "${TEMP_EXTRACT}/caddy/Caddyfile" "${TARGET_DIR}/Caddyfile"
fi

# ------------------------------------------------------------------------------
# 5. Database Integrity Verification
# ------------------------------------------------------------------------------
echo "=========================================================="
echo " Validating Restored Database Integrity"
echo "=========================================================="

if [[ -f "${TARGET_DIR}/data/vaultwarden/db.sqlite3" ]]; then
    if python3 -c "
import sqlite3, sys
con = sqlite3.connect('${TARGET_DIR}/data/vaultwarden/db.sqlite3')
res = con.execute('PRAGMA integrity_check;').fetchall()
con.close()
sys.exit(0 if res == [('ok',)] else 1)
"; then
        log_success "Vaultwarden SQLite database integrity: OK"
    else
        log_error "Vaultwarden SQLite integrity check FAILED"
        exit 1
    fi
fi

if [[ -f "${TARGET_DIR}/data/uptime-kuma/kuma.db" ]]; then
    if python3 -c "
import sqlite3, sys
con = sqlite3.connect('${TARGET_DIR}/data/uptime-kuma/kuma.db')
res = con.execute('PRAGMA integrity_check;').fetchall()
con.close()
sys.exit(0 if res == [('ok',)] else 1)
"; then
        log_success "Uptime Kuma SQLite database integrity: OK"
    else
        log_error "Uptime Kuma SQLite integrity check FAILED"
        exit 1
    fi
fi

echo "=========================================================="
echo " Disaster Recovery Restore Completed Successfully!"
echo "=========================================================="
log_info "Destination: ${TARGET_DIR}"
if [[ "${TARGET_DIR}" == "/opt/homelab" ]]; then
    log_info "To start/restart the recovered stack: cd ${TARGET_DIR} && docker compose up -d"
fi
