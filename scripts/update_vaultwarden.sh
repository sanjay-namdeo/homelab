#!/usr/bin/env bash
# ==============================================================================
# Vaultwarden Minimal Downtime Update Script
# ==============================================================================
# Updates Vaultwarden with near-zero downtime (~1-2s container restart) by:
# 1. Pre-pulling image layers while the service is still active.
# 2. Taking a live point-in-time SQLite snapshot before the restart.
# 3. Hot-recreating the container via Docker Compose.
# 4. Verifying container health and reporting the new version.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root or with sudo: sudo $0"
    exit 1
fi

HOMELAB_DIR="/opt/homelab"
cd "${HOMELAB_DIR}"

echo "=========================================================="
echo " Starting Vaultwarden Minimal Downtime Update"
echo "=========================================================="

# ------------------------------------------------------------------------------
# 1. Pre-pull Docker image in background (Zero Downtime during download)
# ------------------------------------------------------------------------------
log_info "[1/4] Pre-pulling latest Vaultwarden image (service remains online)..."
docker compose pull vaultwarden
log_success "Image layers downloaded successfully."

# ------------------------------------------------------------------------------
# 2. Create Live SQLite Database Snapshot (Safety Point)
# ------------------------------------------------------------------------------
BACKUP_DIR="${HOMELAB_DIR}/data/vaultwarden/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/db_backup_${TIMESTAMP}.sqlite3"

log_info "[2/4] Creating live point-in-time database snapshot..."
mkdir -p "${BACKUP_DIR}"

if [[ -f "${HOMELAB_DIR}/data/vaultwarden/db.sqlite3" ]]; then
    python3 -c "
import sqlite3
src = sqlite3.connect('${HOMELAB_DIR}/data/vaultwarden/db.sqlite3')
dst = sqlite3.connect('${BACKUP_FILE}')
src.backup(dst)
dst.close()
src.close()
"
    log_success "Database snapshot created: ${BACKUP_FILE}"
else
    log_warn "No existing db.sqlite3 found. Skipping database backup."
fi

# ------------------------------------------------------------------------------
# 3. Hot Swap Container (~1-2 Seconds Downtime)
# ------------------------------------------------------------------------------
log_info "[3/4] Recreating Vaultwarden container..."
docker compose up -d vaultwarden
log_success "Container restarted with the latest image."

# ------------------------------------------------------------------------------
# 4. Health Check Verification
# ------------------------------------------------------------------------------
log_info "[4/4] Verifying service health..."
MAX_ATTEMPTS=15
ATTEMPT=0
HEALTHY=false

while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
    STATUS=$(docker inspect --format='{{json .State.Health.Status}}' vaultwarden 2>/dev/null || echo '"unhealthy"')
    if [[ "$STATUS" == '"healthy"' ]]; then
        HEALTHY=true
        break
    fi
    sleep 1
    ATTEMPT=$((ATTEMPT + 1))
done

if [[ "$HEALTHY" == "true" ]]; then
    log_success "Vaultwarden is healthy and serving traffic!"
    VERSION_INFO=$(docker exec vaultwarden /vaultwarden --version 2>&1 | grep -E "Vaultwarden [0-9]" || echo "Running")
    echo "----------------------------------------------------------"
    echo -e "${GREEN}Update Complete:${NC} ${VERSION_INFO}"
    echo -e "${BLUE}Backup Archive:${NC}  ${BACKUP_FILE}"
    echo "----------------------------------------------------------"
else
    log_warn "Healthcheck timed out or reporting unhealthy. Checking logs:"
    docker compose logs --tail=20 vaultwarden
fi
