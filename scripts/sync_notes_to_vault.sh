#!/usr/bin/env bash
# ==============================================================================
# Homelab: Sync Documentation Notes to Obsidian & Flatnotes Vault
# ==============================================================================
# Synchronizes notes into their strictly separated folders:
# - CAMS notes -> notes/CAMS/
# - Homelab notes -> notes/homelab/
# Cleans legacy root clutter, sets UID 82:82 permissions, and syncs to dev1 WebDAV.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

HOMELAB_DIR="/opt/homelab"
WEBDAV_VAULT_DIR="${HOMELAB_DIR}/data/obsidian/vault"
DEV2_VAULT_DIR="${HOMELAB_DIR}/data/dev2/obsidian/vault"
DEV2_INDEX_DIR="${HOMELAB_DIR}/data/dev2/obsidian/flatnotes_data"
NOTES_DIR="${HOMELAB_DIR}/notes"

# Source environment configuration if present
ROOT_ENV="${HOMELAB_DIR}/.env"
if [[ -f "${ROOT_ENV}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${ROOT_ENV}"
    set +a
fi

DEV1_HOST="${DEV1_TAILSCALE_FQDN:-dev1.tail256d6d.ts.net}"
WEBDAV_URL="${WEBDAV_URL:-https://${DEV1_HOST}:8082/data/}"
WEBDAV_USER="${WEBDAV_USERNAME:-obsidian}"
WEBDAV_PASS="${WEBDAV_PASSWORD:-}"

export PATH="/home/${SYSTEM_USER:-$(whoami)}/.local/bin:/usr/local/bin:$PATH"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_warn "Running as non-root user ($(whoami)). Ensure write permissions to vault directories."
fi

cd "${HOMELAB_DIR}"

log_info "1. Validating notes directory structure..."
if [[ ! -d "${NOTES_DIR}/CAMS" || ! -d "${NOTES_DIR}/homelab" ]]; then
    log_error "Required directories ${NOTES_DIR}/CAMS or ${NOTES_DIR}/homelab not found!"
    exit 1
fi

log_info "2. Preparing clean local vault directories..."
# Clean old flat root files and old notes/ subfolder from local vault dirs
for vdir in "${WEBDAV_VAULT_DIR}" "${DEV2_VAULT_DIR}"; do
    mkdir -p "${vdir}/CAMS" "${vdir}/homelab" "${vdir}/attachments"
    # Remove loose .md files at vault root
    find "${vdir}" -maxdepth 1 -name "*.md" -delete 2>/dev/null || true
    # Remove old redundant notes/ folder if present
    rm -rf "${vdir}/notes" 2>/dev/null || true
done
mkdir -p "${DEV2_INDEX_DIR}"

log_info "3. Synchronizing CAMS and Homelab notes to vault folders..."
# Sync CAMS notes
rsync -av --delete "${NOTES_DIR}/CAMS/" "${WEBDAV_VAULT_DIR}/CAMS/" >/dev/null
rsync -av --delete "${NOTES_DIR}/CAMS/" "${DEV2_VAULT_DIR}/CAMS/" >/dev/null

# Sync Homelab notes
rsync -av --delete "${NOTES_DIR}/homelab/" "${WEBDAV_VAULT_DIR}/homelab/" >/dev/null
rsync -av --delete "${NOTES_DIR}/homelab/" "${DEV2_VAULT_DIR}/homelab/" >/dev/null

# Sync .obsidian configs and attachments
for vdir in "${WEBDAV_VAULT_DIR}" "${DEV2_VAULT_DIR}"; do
    [[ -d "${NOTES_DIR}/.obsidian" ]] && cp -r "${NOTES_DIR}/.obsidian" "${vdir}/" 2>/dev/null || true
    [[ -d "${NOTES_DIR}/attachments" ]] && cp -r "${NOTES_DIR}/attachments" "${vdir}/" 2>/dev/null || true
done

log_info "4. Setting permissions for WebDAV and Flatnotes (UID 82:82)..."
chown -R 82:82 "${HOMELAB_DIR}/data/obsidian" "${HOMELAB_DIR}/data/dev2/obsidian" 2>/dev/null || true
chmod -R 777 "${HOMELAB_DIR}/data/obsidian" "${HOMELAB_DIR}/data/dev2/obsidian" 2>/dev/null || true

log_info "5. Resetting Flatnotes search index to trigger full rescan..."
rm -rf "${DEV2_INDEX_DIR:?}"/* 2>/dev/null || true
rm -rf "${DEV2_VAULT_DIR}/.flatnotes" 2>/dev/null || true

log_info "6. Restarting Flatnotes and WebDAV containers if running locally..."
if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^obsidian_web$"; then
    docker restart obsidian_web || true
fi
if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^obsidian_webdav$"; then
    docker restart obsidian_webdav || true
fi

# 7. Push to remote WebDAV server via rclone with sync (prunes remote orphans)
if command -v rclone &>/dev/null && [[ -n "${WEBDAV_PASS}" ]]; then
    log_info "7. Pushing clean vault to remote WebDAV server (${DEV1_HOST}:8082)..."
    RCLONE_PASS=$(rclone obscure "${WEBDAV_PASS}")
    rclone sync \
        --webdav-url "${WEBDAV_URL}" \
        --webdav-user "${WEBDAV_USER}" \
        --webdav-pass "${RCLONE_PASS}" \
        --webdav-vendor other \
        --exclude ".flatnotes/**" \
        --exclude "*_WRITELOCK*" \
        --exclude ".trash/**" \
        "${WEBDAV_VAULT_DIR}" :webdav: -v
fi

echo ""
echo "=========================================================="
log_success "Clean vault structure synchronized successfully!"
echo "=========================================================="
echo "CAMS Notes: $(find "${WEBDAV_VAULT_DIR}/CAMS" -type f -name '*.md' 2>/dev/null | wc -l) files in CAMS/"
echo "Homelab Notes: $(find "${WEBDAV_VAULT_DIR}/homelab" -type f -name '*.md' 2>/dev/null | wc -l) files in homelab/"
echo "=========================================================="
