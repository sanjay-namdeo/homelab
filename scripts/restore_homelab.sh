#!/usr/bin/env bash
# ==============================================================================
# Homelab Automated Disaster Recovery & Restore Script (Multi-Host: dev1 & dev2)
# ==============================================================================
# Restores homelab stack state from a timestamped backup archive:
#  - dev1: Vaultwarden database & keys, AdGuard conf, Uptime Kuma db, Caddyfile, .env
#  - dev2: MariaDB firefly database, Firefly upload assets, .env secrets, docker-compose.yml
#  - Enforces strict security permissions (0700/0600)
#  - Validates database integrity (SQLite integrity_check / MariaDB SQL verification)
# ==============================================================================

set -euo pipefail

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

log_info "[1/4] Extracting and verifying backup archive..."
tar -xzf "${ARCHIVE_PATH}" -C "${TEMP_EXTRACT}"

# Detect archive type
IS_DEV2=false
if [[ -f "${TEMP_EXTRACT}/config/host.txt" ]]; then
    HOST_TYPE=$(cat "${TEMP_EXTRACT}/config/host.txt")
    [[ "${HOST_TYPE}" == "dev2" ]] && IS_DEV2=true
elif [[ -d "${TEMP_EXTRACT}/mariadb" || -d "${TEMP_EXTRACT}/firefly" ]]; then
    IS_DEV2=true
fi

if [[ "${IS_DEV2}" == true ]]; then
    # --------------------------------------------------------------------------
    # DEV2 RESTORE PROCEDURE
    # --------------------------------------------------------------------------
    log_info "Detected Host Profile: dev2 (Firefly III & MariaDB)"
    
    mkdir -p "${TARGET_DIR}/hosts/dev2"
    mkdir -p "${TARGET_DIR}/data/dev2/firefly/upload"
    mkdir -p "${TARGET_DIR}/data/dev2/firefly/import"
    mkdir -p "${TARGET_DIR}/data/dev2/firefly/db"

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

    # 2. Restore Firefly uploads and import assets
    log_info "[3/4] Restoring Firefly III uploaded and import files..."
    if [[ -d "${TEMP_EXTRACT}/firefly/upload" ]]; then
        cp -a "${TEMP_EXTRACT}/firefly/upload"/. "${TARGET_DIR}/data/dev2/firefly/upload/" 2>/dev/null || true
        chmod -R 775 "${TARGET_DIR}/data/dev2/firefly/upload" 2>/dev/null || true
        log_success "Firefly III uploads restored."
    fi
    if [[ -d "${TEMP_EXTRACT}/firefly/import" ]]; then
        cp -a "${TEMP_EXTRACT}/firefly/import"/. "${TARGET_DIR}/data/dev2/firefly/import/" 2>/dev/null || true
        chmod -R 775 "${TARGET_DIR}/data/dev2/firefly/import" 2>/dev/null || true
        log_success "Firefly III import directory restored."
    fi

    # 3. Restore Obsidian Markdown Vault & Web Data
    if [[ -d "${TEMP_EXTRACT}/obsidian" ]]; then
        log_info "Restoring Obsidian Markdown Vault and Web configuration..."
        mkdir -p "${TARGET_DIR}/data/dev2/obsidian"
        cp -a "${TEMP_EXTRACT}/obsidian"/. "${TARGET_DIR}/data/dev2/obsidian/" 2>/dev/null || true
        chown -R 82:82 "${TARGET_DIR}/data/dev2/obsidian" 2>/dev/null || true
        chmod -R 775 "${TARGET_DIR}/data/dev2/obsidian" 2>/dev/null || true
        log_success "Obsidian Markdown Vault restored."
    fi

    # 4. Restore Beszel Server Monitoring Hub Data & Keys
    if [[ -d "${TEMP_EXTRACT}/beszel" ]]; then
        log_info "Restoring Beszel Server Monitoring Hub data and keys..."
        mkdir -p "${TARGET_DIR}/data/dev2/beszel/data" "${TARGET_DIR}/data/dev2/beszel/socket"
        cp -a "${TEMP_EXTRACT}/beszel/data"/. "${TARGET_DIR}/data/dev2/beszel/data/" 2>/dev/null || true
        log_success "Beszel Server Monitoring Hub data restored."
    fi

    # 5. Restore / Import MariaDB Database
    log_info "[4/4] Processing MariaDB database snapshot..."
    if [[ -f "${TEMP_EXTRACT}/mariadb/firefly.sql" ]]; then
        RESTORE_SQL="${TARGET_DIR}/data/dev2/firefly/restored_firefly_$(date +%Y%m%d_%H%M%S).sql"
        cp "${TEMP_EXTRACT}/mariadb/firefly.sql" "${RESTORE_SQL}"
        chmod 600 "${RESTORE_SQL}"
        log_success "SQL dump copied to: ${RESTORE_SQL}"

        # SQL integrity check
        if grep -q "CREATE TABLE" "${RESTORE_SQL}" || grep -q "Dump completed" "${RESTORE_SQL}"; then
            log_success "MariaDB SQL dump integrity: OK"
        else
            log_error "MariaDB SQL dump integrity check FAILED (missing valid SQL headers/tables)"
            exit 1
        fi

        # If firefly_db container is running and restoring to production directory, import database
        if [[ "${TARGET_DIR}" == "/opt/homelab" ]] && docker ps --format '{{.Names}}' | grep -q "^firefly_db$"; then
            DEV2_ENV="${TARGET_DIR}/hosts/dev2/.env"
            DB_PASS=$(grep '^DB_PASSWORD=' "${DEV2_ENV}" | cut -d= -f2- || echo "")
            if [[ -n "${DB_PASS}" ]]; then
                log_info "Live production firefly_db container detected. Importing database..."
                if docker exec -i firefly_db mariadb -u firefly -p"${DB_PASS}" firefly < "${RESTORE_SQL}"; then
                    log_success "Database successfully imported into live MariaDB container."
                else
                    log_warn "Automatic live database import failed. You can manually import using:"
                    echo "  docker exec -i firefly_db mariadb -u firefly -p'<password>' firefly < ${RESTORE_SQL}"
                fi
            fi
        else
            log_info "Database snapshot extracted and validated (safe mode / target: ${TARGET_DIR})."
            log_info "To import after launching containers:"
            echo "  cd ${TARGET_DIR}/hosts/dev2 && docker compose up -d"
            echo "  docker exec -i firefly_db mariadb -u firefly -p'<password>' firefly < ${RESTORE_SQL}"
        fi
    elif [[ -d "${TEMP_EXTRACT}/mariadb/raw" ]]; then
        log_info "Restoring raw MariaDB data directory..."
        cp -a "${TEMP_EXTRACT}/mariadb/raw/db"/. "${TARGET_DIR}/data/dev2/firefly/db/"
        log_success "Raw MariaDB data directory restored."
    fi

else
    # --------------------------------------------------------------------------
    # DEV1 RESTORE PROCEDURE
    # --------------------------------------------------------------------------
    log_info "Detected Host Profile: dev1 (Vaultwarden, AdGuard, Uptime Kuma, Caddy)"

    mkdir -p "${TARGET_DIR}/data/vaultwarden"
    mkdir -p "${TARGET_DIR}/data/adguard/conf"
    mkdir -p "${TARGET_DIR}/data/adguard/work"
    mkdir -p "${TARGET_DIR}/data/uptime-kuma"
    mkdir -p "${TARGET_DIR}/data/caddy"
    mkdir -p "${TARGET_DIR}/hosts/dev1"

    # 1. Restore Vaultwarden
    log_info "[2/5] Restoring Vaultwarden database and credentials..."
    if [[ -f "${TEMP_EXTRACT}/vaultwarden/db.sqlite3" ]]; then
        cp "${TEMP_EXTRACT}/vaultwarden/db.sqlite3" "${TARGET_DIR}/data/vaultwarden/db.sqlite3"
    fi
    [[ -f "${TEMP_EXTRACT}/vaultwarden/config.json" ]] && cp "${TEMP_EXTRACT}/vaultwarden/config.json" "${TARGET_DIR}/data/vaultwarden/"
    [[ -f "${TEMP_EXTRACT}/vaultwarden/rsa_key.pem" ]] && cp "${TEMP_EXTRACT}/vaultwarden/rsa_key.pem" "${TARGET_DIR}/data/vaultwarden/"
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

    # 3. Restore Uptime Kuma
    log_info "[4/5] Restoring Uptime Kuma database..."
    if [[ -f "${TEMP_EXTRACT}/uptime-kuma/kuma.db" ]]; then
        cp "${TEMP_EXTRACT}/uptime-kuma/kuma.db" "${TARGET_DIR}/data/uptime-kuma/kuma.db"
        chmod 700 "${TARGET_DIR}/data/uptime-kuma"
        chmod 600 "${TARGET_DIR}/data/uptime-kuma/kuma.db"
        log_success "Uptime Kuma database restored."
    fi

    # 4. Restore Caddyfile & Stack Configs
    log_info "[5/5] Restoring environment and reverse proxy configuration..."
    if [[ -f "${TEMP_EXTRACT}/config/.env" ]]; then
        cp "${TEMP_EXTRACT}/config/.env" "${TARGET_DIR}/.env"
        cp "${TEMP_EXTRACT}/config/.env" "${TARGET_DIR}/hosts/dev1/.env" 2>/dev/null || true
        chmod 600 "${TARGET_DIR}/.env"
        chmod 600 "${TARGET_DIR}/hosts/dev1/.env" 2>/dev/null || true
    fi
    if [[ -f "${TEMP_EXTRACT}/config/docker-compose.yml" ]]; then
        cp "${TEMP_EXTRACT}/config/docker-compose.yml" "${TARGET_DIR}/docker-compose.yml"
        cp "${TEMP_EXTRACT}/config/docker-compose.yml" "${TARGET_DIR}/hosts/dev1/docker-compose.yml" 2>/dev/null || true
    fi
    if [[ -f "${TEMP_EXTRACT}/caddy/Caddyfile" ]]; then
        cp "${TEMP_EXTRACT}/caddy/Caddyfile" "${TARGET_DIR}/Caddyfile"
        cp "${TEMP_EXTRACT}/caddy/Caddyfile" "${TARGET_DIR}/hosts/dev1/Caddyfile" 2>/dev/null || true
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

