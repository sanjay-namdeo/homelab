#!/usr/bin/env bash
# ==============================================================================
# Homelab Automated Disaster Recovery & Restore Script (Multi-Host: dev1 & dev2)
# ==============================================================================
# Restores homelab stack state from a timestamped backup archive:
#  - dev1: Vaultwarden database & keys, AdGuard conf, Obsidian WebDAV, Caddyfile, .env
#  - dev2: Obsidian Markdown Vault & Flatnotes data, Beszel Hub metrics & keys, .env secrets, docker-compose.yml
#  - Enforces strict security permissions (0700/0600)
#  - Validates database integrity (SQLite integrity_check)
# ==============================================================================

set -euo pipefail

export PATH="/home/sanjay-namdeo/.local/bin:/usr/local/bin:$PATH"

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

usage() {
    echo "Usage: sudo $0 <path_to_backup_archive.tar.gz> [--target-dir <directory>]"
    echo ""
    echo "Options:"
    echo "  --target-dir <dir>   Restore destination directory (default: /opt/homelab)"
    echo "  -h, --help           Show this help message"
    exit 1
}

ARCHIVE_PATH=""
TARGET_DIR="/opt/homelab"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --latest)
            LATEST_FOUND=$(find /opt/homelab/data/backups -name "homelab_backup_*.tar.gz" -type f 2>/dev/null | sort -r | head -n 1 || echo "")
            if [[ -n "${LATEST_FOUND}" && -f "${LATEST_FOUND}" ]]; then
                ARCHIVE_PATH="${LATEST_FOUND}"
            else
                log_error "No backup archives found in /opt/homelab/data/backups"
                exit 1
            fi
            shift 1
            ;;
        --archive)
            ARCHIVE_PATH="$2"
            shift 2
            ;;
        --target-dir)
            TARGET_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "${ARCHIVE_PATH}" && "$1" != --* ]]; then
                ARCHIVE_PATH="$1"
                shift 1
            else
                log_error "Unknown option: $1"
                usage
            fi
            ;;
    esac
done

if [[ -z "${ARCHIVE_PATH}" ]]; then
    log_error "No backup archive specified. Pass path to archive or use --latest"
    usage
fi

if [[ $EUID -ne 0 ]]; then
    log_warn "Running as non-root user ($(whoami)). Target directory must be writable."
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

log_info "[1/4] Extracting and verifying backup archive..."
tar -xzf "${ARCHIVE_PATH}" -C "${TEMP_EXTRACT}"

# Detect archive type
IS_DEV2=false
if [[ -f "${TEMP_EXTRACT}/config/host.txt" ]]; then
    HOST_TYPE=$(cat "${TEMP_EXTRACT}/config/host.txt")
    [[ "${HOST_TYPE}" == "dev2" ]] && IS_DEV2=true
elif [[ -d "${TEMP_EXTRACT}/obsidian" || -d "${TEMP_EXTRACT}/beszel" || -d "${TEMP_EXTRACT}/gatus" ]]; then
    IS_DEV2=true
fi

if [[ "${IS_DEV2}" == true ]]; then
    # --------------------------------------------------------------------------
    # DEV2 RESTORE PROCEDURE
    # --------------------------------------------------------------------------
    log_info "Detected Host Profile: dev2 (Obsidian, Beszel Hub, & Gatus Status Dashboard)"
    
    mkdir -p "${TARGET_DIR}/hosts/dev2" "${TARGET_DIR}/hosts/dev2/gatus"

    # 1. Restore Environment & Compose definitions
    log_info "[2/4] Restoring dev2 environment secrets and compose file..."
    if [[ -f "${TEMP_EXTRACT}/config/.env" ]]; then
        cp "${TEMP_EXTRACT}/config/.env" "${TARGET_DIR}/hosts/dev2/.env"
        chmod 600 "${TARGET_DIR}/hosts/dev2/.env"
        log_success "Environment secrets restored (${TARGET_DIR}/hosts/dev2/.env)."
    fi
    if [[ -f "${TEMP_EXTRACT}/config/docker-compose.yml" ]]; then
        cp "${TEMP_EXTRACT}/config/docker-compose.yml" "${TARGET_DIR}/hosts/dev2/docker-compose.yml"
        log_success "Compose definition restored (${TARGET_DIR}/hosts/dev2/docker-compose.yml)."
    fi

    # 2. Restore Obsidian Markdown Vault & Web Data
    log_info "[3/4] Restoring Obsidian Markdown Vault, Beszel Hub, & Gatus data..."
    if [[ -d "${TEMP_EXTRACT}/obsidian" ]]; then
        log_info "Restoring Obsidian Markdown Vault and Web configuration..."
        mkdir -p "${TARGET_DIR}/data/dev2/obsidian"
        cp -a "${TEMP_EXTRACT}/obsidian"/. "${TARGET_DIR}/data/dev2/obsidian/" 2>/dev/null || true
        chown -R 82:82 "${TARGET_DIR}/data/dev2/obsidian" 2>/dev/null || true
        chmod -R 775 "${TARGET_DIR}/data/dev2/obsidian" 2>/dev/null || true
        log_success "Obsidian Markdown Vault restored."
    fi

    # 3. Restore Beszel Server Monitoring Hub Data & Keys
    if [[ -d "${TEMP_EXTRACT}/beszel" ]]; then
        log_info "Restoring Beszel Server Monitoring Hub data and keys..."
        mkdir -p "${TARGET_DIR}/data/dev2/beszel/data" "${TARGET_DIR}/data/dev2/beszel/socket"
        cp -a "${TEMP_EXTRACT}/beszel/data"/. "${TARGET_DIR}/data/dev2/beszel/data/" 2>/dev/null || true
        log_success "Beszel Server Monitoring Hub data restored."
    fi

    # 4. Restore Gatus Status Dashboard Data & Configuration
    if [[ -d "${TEMP_EXTRACT}/gatus" ]]; then
        log_info "Restoring Gatus Status Dashboard database and configuration..."
        mkdir -p "${TARGET_DIR}/data/dev2/gatus" "${TARGET_DIR}/hosts/dev2/gatus"
        if [[ -f "${TEMP_EXTRACT}/gatus/gatus.db" ]]; then
            cp "${TEMP_EXTRACT}/gatus/gatus.db" "${TARGET_DIR}/data/dev2/gatus/gatus.db"
            chmod 600 "${TARGET_DIR}/data/dev2/gatus/gatus.db"
        fi
        if [[ -f "${TEMP_EXTRACT}/gatus/config.yaml" ]]; then
            cp "${TEMP_EXTRACT}/gatus/config.yaml" "${TARGET_DIR}/hosts/dev2/gatus/config.yaml"
        fi
        log_success "Gatus Status Dashboard files restored."
    fi

    # 5. Database Integrity Verification (dev2)
    echo "=========================================================="
    echo " Validating Restored Database Integrity"
    echo "=========================================================="
    if [[ -f "${TARGET_DIR}/data/dev2/beszel/data/data.db" ]]; then
        if python3 -c "
import sqlite3, sys
con = sqlite3.connect('${TARGET_DIR}/data/dev2/beszel/data/data.db')
res = con.execute('PRAGMA integrity_check;').fetchall()
con.close()
sys.exit(0 if res == [('ok',)] else 1)
"; then
            log_success "Beszel Hub SQLite database integrity: OK"
        else
            log_error "Beszel Hub SQLite integrity check FAILED"
            exit 1
        fi
    fi

    if [[ -f "${TARGET_DIR}/data/dev2/gatus/gatus.db" ]]; then
        if python3 -c "
import sqlite3, sys
con = sqlite3.connect('${TARGET_DIR}/data/dev2/gatus/gatus.db')
res = con.execute('PRAGMA integrity_check;').fetchall()
con.close()
sys.exit(0 if res == [('ok',)] else 1)
"; then
            log_success "Gatus SQLite database integrity: OK"
        else
            log_error "Gatus SQLite integrity check FAILED"
            exit 1
        fi
    fi

else
    # --------------------------------------------------------------------------
    # DEV1 RESTORE PROCEDURE
    # --------------------------------------------------------------------------
    log_info "Detected Host Profile: dev1 (Vaultwarden, AdGuard, Obsidian WebDAV, Caddy)"

    mkdir -p "${TARGET_DIR}/data/vaultwarden"
    mkdir -p "${TARGET_DIR}/data/adguard/conf"
    mkdir -p "${TARGET_DIR}/data/adguard/work"
    mkdir -p "${TARGET_DIR}/data/obsidian/vault"
    mkdir -p "${TARGET_DIR}/data/caddy"
    mkdir -p "${TARGET_DIR}/hosts/dev1"

    # 1. Restore Vaultwarden
    log_info "[2/5] Restoring Vaultwarden database and credentials..."
    if [[ -f "${TEMP_EXTRACT}/vaultwarden/db.sqlite3" ]]; then
        cp "${TEMP_EXTRACT}/vaultwarden/db.sqlite3" "${TARGET_DIR}/data/vaultwarden/db.sqlite3"
    fi
    [[ -f "${TEMP_EXTRACT}/vaultwarden/config.json" ]] && cp "${TEMP_EXTRACT}/vaultwarden/config.json" "${TARGET_DIR}/data/vaultwarden/"
    [[ -f "${TEMP_EXTRACT}/vaultwarden/rsa_key.pem" ]] && cp "${TEMP_EXTRACT}/vaultwarden/rsa_key.pem" "${TARGET_DIR}/data/vaultwarden/"
    [[ -d "${TEMP_EXTRACT}/vaultwarden/attachments" ]] && cp -a "${TEMP_EXTRACT}/vaultwarden/attachments" "${TARGET_DIR}/data/vaultwarden/"
    [[ -d "${TEMP_EXTRACT}/vaultwarden/sends" ]] && cp -a "${TEMP_EXTRACT}/vaultwarden/sends" "${TARGET_DIR}/data/vaultwarden/"
    chmod 700 "${TARGET_DIR}/data/vaultwarden"
    chmod 600 "${TARGET_DIR}/data/vaultwarden/db.sqlite3" 2>/dev/null || true
    chmod 600 "${TARGET_DIR}/data/vaultwarden/config.json" 2>/dev/null || true
    chmod 600 "${TARGET_DIR}/data/vaultwarden/rsa_key.pem" 2>/dev/null || true
    log_success "Vaultwarden files restored."

    # 2. Restore AdGuard Home
    log_info "[3/5] Restoring AdGuard Home configuration..."
    if [[ -d "${TEMP_EXTRACT}/adguard/conf" ]]; then
        cp -r "${TEMP_EXTRACT}/adguard/conf"/* "${TARGET_DIR}/data/adguard/conf/" 2>/dev/null || true
        chmod 700 "${TARGET_DIR}/data/adguard"
        chmod 700 "${TARGET_DIR}/data/adguard/conf"
        chmod 600 "${TARGET_DIR}/data/adguard/conf/AdGuardHome.yaml" 2>/dev/null || true
        log_success "AdGuard Home configuration restored."
    fi

    # 3. Restore Obsidian Markdown Vault
    log_info "[4/5] Restoring primary Obsidian Markdown Vault on dev1..."
    if [[ -d "${TEMP_EXTRACT}/obsidian" ]]; then
        cp -a "${TEMP_EXTRACT}/obsidian"/. "${TARGET_DIR}/data/obsidian/" 2>/dev/null || true
        chown -R 82:82 "${TARGET_DIR}/data/obsidian" 2>/dev/null || true
        chmod -R 775 "${TARGET_DIR}/data/obsidian" 2>/dev/null || true
        log_success "Obsidian Markdown Vault restored."
    fi

    # 4. Restore Caddyfile & Stack Configs
    log_info "[5/5] Restoring environment and reverse proxy configuration..."
    if [[ -f "${TEMP_EXTRACT}/config/.env" ]]; then
        cp "${TEMP_EXTRACT}/config/.env" "${TARGET_DIR}/.env"
        cp "${TEMP_EXTRACT}/config/.env" "${TARGET_DIR}/hosts/dev1/.env" 2>/dev/null || true
        chmod 600 "${TARGET_DIR}/.env"
        chmod 600 "${TARGET_DIR}/hosts/dev1/.env" 2>/dev/null || true
    fi
    if [[ -f "${TEMP_EXTRACT}/config/.env.dev1" ]]; then
        cp "${TEMP_EXTRACT}/config/.env.dev1" "${TARGET_DIR}/hosts/dev1/.env"
        chmod 600 "${TARGET_DIR}/hosts/dev1/.env"
    fi
    if [[ -f "${TEMP_EXTRACT}/config/docker-compose.yml" ]]; then
        cp "${TEMP_EXTRACT}/config/docker-compose.yml" "${TARGET_DIR}/docker-compose.yml"
        cp "${TEMP_EXTRACT}/config/docker-compose.yml" "${TARGET_DIR}/hosts/dev1/docker-compose.yml" 2>/dev/null || true
    fi
    if [[ -f "${TEMP_EXTRACT}/config/docker-compose.dev1.yml" ]]; then
        cp "${TEMP_EXTRACT}/config/docker-compose.dev1.yml" "${TARGET_DIR}/hosts/dev1/docker-compose.yml"
    fi
    if [[ -f "${TEMP_EXTRACT}/caddy/Caddyfile" ]]; then
        cp "${TEMP_EXTRACT}/caddy/Caddyfile" "${TARGET_DIR}/Caddyfile"
        cp "${TEMP_EXTRACT}/caddy/Caddyfile" "${TARGET_DIR}/hosts/dev1/Caddyfile" 2>/dev/null || true
    fi
    if [[ -f "${TEMP_EXTRACT}/caddy/Caddyfile.host" ]]; then
        cp "${TEMP_EXTRACT}/caddy/Caddyfile.host" "${TARGET_DIR}/hosts/dev1/Caddyfile"
    fi
    if [[ -d "${TEMP_EXTRACT}/caddy/data" ]]; then
        mkdir -p "${TARGET_DIR}/data/caddy/data"
        cp -a "${TEMP_EXTRACT}/caddy/data"/. "${TARGET_DIR}/data/caddy/data/" 2>/dev/null || true
    fi

    # 5. Database Integrity Verification
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
fi

echo "=========================================================="
echo " Disaster Recovery Restore Completed Successfully!"
echo "=========================================================="
log_info "Destination: ${TARGET_DIR}"
if [[ "${IS_DEV2}" == true ]]; then
    log_info "To manage/start stack: cd ${TARGET_DIR}/hosts/dev2 && docker compose up -d"
else
    log_info "To manage/start stack: cd ${TARGET_DIR} && docker compose up -d"
fi

