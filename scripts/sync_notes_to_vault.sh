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
VAULT_DIR="${HOMELAB_DIR}/data/dev2/obsidian/vault"
INDEX_DIR="${HOMELAB_DIR}/data/dev2/obsidian/flatnotes_data"
NOTES_DIR="${HOMELAB_DIR}/notes"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root or with sudo: sudo $0"
    exit 1
fi

cd "${HOMELAB_DIR}"

log_info "1. Checking git notes directory..."
if [[ ! -d "${NOTES_DIR}" ]]; then
    log_error "Notes directory ${NOTES_DIR} not found!"
    exit 1
fi

log_info "2. Preparing live vault directory (${VAULT_DIR})..."
mkdir -p "${VAULT_DIR}"
mkdir -p "${INDEX_DIR}"

log_info "3. Preparing Obsidian/Flatnotes vault directories..."
mkdir -p "${VAULT_DIR}/notes/homelab"
mkdir -p "${VAULT_DIR}/attachments"

log_info "4. Synchronizing all structured markdown notes to vault root and notes/..."
# Copy all structured notes to vault root
cp -v "${NOTES_DIR}"/*.md "${VAULT_DIR}/" 2>/dev/null || true
[[ -d "${NOTES_DIR}/.obsidian" ]] && cp -r "${NOTES_DIR}/.obsidian" "${VAULT_DIR}/" 2>/dev/null || true
[[ -d "${NOTES_DIR}/attachments" ]] && cp -r "${NOTES_DIR}/attachments" "${VAULT_DIR}/" 2>/dev/null || true

# Also copy all notes into notes/ subdirectory for Obsidian clients configured with a notes/ subfolder
cp -v "${NOTES_DIR}"/*.md "${VAULT_DIR}/notes/" 2>/dev/null || true

# Populate legacy-named files in notes/ for clients with existing file references
cp "${NOTES_DIR}/00 - Homelab Hub.md" "${VAULT_DIR}/notes/00 - Homelab Overview & Architecture.md" 2>/dev/null || true
cp "${NOTES_DIR}/02 - Service - Vaultwarden.md" "${VAULT_DIR}/notes/Service - Vaultwarden.md" 2>/dev/null || true
cp "${NOTES_DIR}/02 - Service - AdGuard Home.md" "${VAULT_DIR}/notes/Service - AdGuard Home.md" 2>/dev/null || true
cp "${NOTES_DIR}/02 - Service - Uptime Kuma.md" "${VAULT_DIR}/notes/Service - Uptime Kuma.md" 2>/dev/null || true
cp "${NOTES_DIR}/02 - Service - Obsidian Sync & Flatnotes.md" "${VAULT_DIR}/notes/Service - Obsidian Sync & Flatnotes.md" 2>/dev/null || true
cp "${NOTES_DIR}/02 - Service - Beszel Server Monitoring.md" "${VAULT_DIR}/notes/Service - Beszel Server Monitoring.md" 2>/dev/null || true
cp "${NOTES_DIR}/02 - Service - Caddy Reverse Proxy.md" "${VAULT_DIR}/notes/Service - Caddy Reverse Proxy.md" 2>/dev/null || true
cp "${NOTES_DIR}/02 - Service - Tailscale WireGuard Mesh.md" "${VAULT_DIR}/notes/Service - Tailscale WireGuard Mesh.md" 2>/dev/null || true
cp "${NOTES_DIR}/03 - Guide - Operations, Maintenance & Troubleshooting.md" "${VAULT_DIR}/notes/Guide - Operations, Maintenance & Troubleshooting.md" 2>/dev/null || true
cp "${NOTES_DIR}/04 - Disaster Recovery - Backup & Off-Site Sync (Cloudflare R2).md" "${VAULT_DIR}/notes/Guide - Backup & Off-Site Sync.md" 2>/dev/null || true
cp "${NOTES_DIR}/04 - Disaster Recovery - Disaster Recovery & Restore.md" "${VAULT_DIR}/notes/Guide - Disaster Recovery & Restore.md" 2>/dev/null || true
cp "${NOTES_DIR}/03 - Guide - Notifications & Alerting (Telegram, Pushover, Email).md" "${VAULT_DIR}/notes/Notifications  - Telegram.md" 2>/dev/null || true
cp "${NOTES_DIR}/03 - Guide - Beszel Multi-Node Monitoring Setup.md" "${VAULT_DIR}/notes/homelab/Beszel Monitoring Setup.md" 2>/dev/null || true
cp "${NOTES_DIR}/03 - Guide - Obsidian Multi-Device Setup & Remotely Save.md" "${VAULT_DIR}/notes/homelab/Obsidian setup.md" 2>/dev/null || true


log_info "5. Setting permissions for Flatnotes and WebDAV (UID 82:82)..."
chown -R 82:82 "${HOMELAB_DIR}/data/dev2/obsidian" 2>/dev/null || true
chmod -R 777 "${HOMELAB_DIR}/data/dev2/obsidian"

log_info "6. Resetting Flatnotes search index to trigger full rescan..."
rm -rf "${INDEX_DIR:?}"/* 2>/dev/null || true
rm -rf "${VAULT_DIR}/.flatnotes" 2>/dev/null || true

log_info "7. Restarting Flatnotes and WebDAV containers..."
if docker ps -a --format '{{.Names}}' | grep -q "^obsidian_web$"; then
    docker restart obsidian_web || true
fi
if docker ps -a --format '{{.Names}}' | grep -q "^obsidian_webdav$"; then
    docker restart obsidian_webdav || true
fi

echo ""
echo "=========================================================="
log_success "All notes synchronized to Obsidian & Flatnotes successfully!"
echo "=========================================================="
echo "Notes in Vault ($(ls -1 "${VAULT_DIR}"/*.md 2>/dev/null | wc -l) notes):"
ls -1 "${VAULT_DIR}"/*.md 2>/dev/null | xargs -n 1 basename
echo "=========================================================="
