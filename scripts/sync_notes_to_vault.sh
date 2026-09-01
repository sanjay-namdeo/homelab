#!/usr/bin/env bash
# ==============================================================================
# Homelab: Sync Documentation Notes to Obsidian & Flatnotes Vault
# ==============================================================================
# Synchronizes all organized notes to the live Obsidian / Flatnotes vault,
# enforces WebDAV & Flatnotes permissions (UID 82), cleans search index cache,
# and restarts Flatnotes / WebDAV.
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

log_info "1. Checking git notes directory..."
if [[ ! -d "${NOTES_DIR}" ]]; then
    log_error "Notes directory ${NOTES_DIR} not found!"
    exit 1
fi

log_info "2. Preparing live vault directories..."
mkdir -p "${WEBDAV_VAULT_DIR}" "${DEV2_VAULT_DIR}" "${DEV2_INDEX_DIR}"
mkdir -p "${WEBDAV_VAULT_DIR}/notes/homelab" "${DEV2_VAULT_DIR}/notes/homelab"
mkdir -p "${WEBDAV_VAULT_DIR}/attachments" "${DEV2_VAULT_DIR}/attachments"

log_info "3. Synchronizing all structured markdown notes to WebDAV and Flatnotes vaults..."
# Copy all structured notes to vault roots and notes/, preserving nested folder structure.
find "${NOTES_DIR}" -type f -name '*.md' -print0 | while IFS= read -r -d '' file; do
    rel_path="${file#${NOTES_DIR}/}"
    filename="$(basename "${file}")"
    
    # dev1 WebDAV target paths
    target_dav_rel="${WEBDAV_VAULT_DIR}/${rel_path}"
    target_dav_notes="${WEBDAV_VAULT_DIR}/notes/${rel_path}"
    mkdir -p "$(dirname "${target_dav_rel}")" "$(dirname "${target_dav_notes}")"
    cp "${file}" "${target_dav_rel}"
    cp "${file}" "${target_dav_notes}"

    # Flat root copy for Flatnotes web search indexing
    cp "${file}" "${WEBDAV_VAULT_DIR}/${filename}"
    cp "${file}" "${DEV2_VAULT_DIR}/${filename}"

    # dev2 Flatnotes target paths
    target_fn_rel="${DEV2_VAULT_DIR}/${rel_path}"
    target_fn_notes="${DEV2_VAULT_DIR}/notes/${rel_path}"
    mkdir -p "$(dirname "${target_fn_rel}")" "$(dirname "${target_fn_notes}")"
    cp "${file}" "${target_fn_rel}"
    cp "${file}" "${target_fn_notes}"
done

# Copy .obsidian configs and attachments to both vaults
for vdir in "${WEBDAV_VAULT_DIR}" "${DEV2_VAULT_DIR}"; do
    [[ -d "${NOTES_DIR}/.obsidian" ]] && cp -r "${NOTES_DIR}/.obsidian" "${vdir}/" 2>/dev/null || true
    [[ -d "${NOTES_DIR}/attachments" ]] && cp -r "${NOTES_DIR}/attachments" "${vdir}/" 2>/dev/null || true

    # Populate legacy-named files in notes/ for clients with existing file references
    cp "${NOTES_DIR}/00 - Homelab Hub.md" "${vdir}/notes/00 - Homelab Overview & Architecture.md" 2>/dev/null || true
    cp "${NOTES_DIR}/02 - Service - Vaultwarden.md" "${vdir}/notes/Service - Vaultwarden.md" 2>/dev/null || true
    cp "${NOTES_DIR}/02 - Service - AdGuard Home.md" "${vdir}/notes/Service - AdGuard Home.md" 2>/dev/null || true
    cp "${NOTES_DIR}/02 - Service - Gatus.md" "${vdir}/notes/Service - Gatus.md" 2>/dev/null || true
    cp "${NOTES_DIR}/02 - Service - Obsidian Sync & Flatnotes.md" "${vdir}/notes/Service - Obsidian Sync & Flatnotes.md" 2>/dev/null || true
    cp "${NOTES_DIR}/02 - Service - Beszel Server Monitoring.md" "${vdir}/notes/Service - Beszel Server Monitoring.md" 2>/dev/null || true
    cp "${NOTES_DIR}/02 - Service - Caddy Reverse Proxy.md" "${vdir}/notes/Service - Caddy Reverse Proxy.md" 2>/dev/null || true
    cp "${NOTES_DIR}/02 - Service - Tailscale WireGuard Mesh.md" "${vdir}/notes/Service - Tailscale WireGuard Mesh.md" 2>/dev/null || true
    cp "${NOTES_DIR}/03 - Guide - Operations, Maintenance & Troubleshooting.md" "${vdir}/notes/Guide - Operations, Maintenance & Troubleshooting.md" 2>/dev/null || true
    cp "${NOTES_DIR}/04 - Disaster Recovery - Backup & Off-Site Sync (Cloudflare R2).md" "${vdir}/notes/Guide - Backup & Off-Site Sync.md" 2>/dev/null || true
    cp "${NOTES_DIR}/04 - Disaster Recovery - Disaster Recovery & Restore.md" "${vdir}/notes/Guide - Disaster Recovery & Restore.md" 2>/dev/null || true
    cp "${NOTES_DIR}/03 - Guide - Notifications & Alerting (Telegram, Pushover, Email).md" "${vdir}/notes/Notifications  - Telegram.md" 2>/dev/null || true
    cp "${NOTES_DIR}/03 - Guide - Beszel Multi-Node Monitoring Setup.md" "${vdir}/notes/homelab/Beszel Monitoring Setup.md" 2>/dev/null || true
    cp "${NOTES_DIR}/03 - Guide - Obsidian Multi-Device Setup & Remotely Save.md" "${vdir}/notes/homelab/Obsidian setup.md" 2>/dev/null || true
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

# 7. Push to remote WebDAV server via rclone if configured
if command -v rclone &>/dev/null && [[ -n "${WEBDAV_PASS}" ]]; then
    log_info "7. Pushing vault to remote WebDAV server (${DEV1_HOST}:8082)..."
    RCLONE_PASS=$(rclone obscure "${WEBDAV_PASS}")
    rclone copy \
        --webdav-url "${WEBDAV_URL}" \
        --webdav-user "${WEBDAV_USER}" \
        --webdav-pass "${RCLONE_PASS}" \
        --webdav-vendor other \
        --exclude ".flatnotes/**" \
        --exclude "*_WRITELOCK*" \
        --exclude ".trash/**" \
        "${WEBDAV_VAULT_DIR}" :webdav: 2>/dev/null || true
fi

echo ""
echo "=========================================================="
log_success "All notes synchronized to WebDAV & Flatnotes successfully!"
echo "=========================================================="
echo "Notes in WebDAV Vault (${WEBDAV_VAULT_DIR}): $(find "${WEBDAV_VAULT_DIR}" -type f -name '*.md' 2>/dev/null | wc -l) files"
echo "Notes in Flatnotes Vault (${DEV2_VAULT_DIR}): $(find "${DEV2_VAULT_DIR}" -type f -name '*.md' 2>/dev/null | wc -l) files"
echo "=========================================================="
