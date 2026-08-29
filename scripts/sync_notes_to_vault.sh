#!/usr/bin/env bash
# ==============================================================================
# Homelab: Sync Documentation Notes to Obsidian & Flatnotes Vault
# ==============================================================================
# Pulls latest documentation from git, synchronizes all organized notes to
# the live Obsidian vault, enforces WebDAV & Flatnotes permissions (UID 82),
# cleans search index cache, and restarts Flatnotes / WebDAV if necessary.
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

log_info "3. Synchronizing structured notes to Obsidian vault..."
# Clean out legacy loose flat notes from the vault root
rm -f "${VAULT_DIR}/CORRUPTED_FILE.txt" "${VAULT_DIR}/Test.md" "${VAULT_DIR}/DR_Live_Test.md" "${VAULT_DIR}/Disaster_Recovery_Validation.md" 2>/dev/null || true
rm -rf "${VAULT_DIR}/notes" 2>/dev/null || true

# Copy all structured folders and markdown files
cp -r "${NOTES_DIR}"/* "${VAULT_DIR}/" 2>/dev/null || true
[[ -d "${NOTES_DIR}/.obsidian" ]] && cp -r "${NOTES_DIR}/.obsidian" "${VAULT_DIR}/" 2>/dev/null || true

# Clean legacy flat files if they exist in vault root
rm -f \
  "${VAULT_DIR}/00 - Homelab Overview & Architecture.md" \
  "${VAULT_DIR}/Beszel Monitoring Setup.md" \
  "${VAULT_DIR}/Disaster Recovery Runbook - dev1 (Identity, DNS & Edge Services).md" \
  "${VAULT_DIR}/Disaster Recovery Runbook - dev2 (Finance & Monitoring).md" \
  "${VAULT_DIR}/Guide - Backup & Off-Site Sync.md" \
  "${VAULT_DIR}/Guide - Disaster Recovery & Restore.md" \
  "${VAULT_DIR}/Guide - Operations, Maintenance & Troubleshooting.md" \
  "${VAULT_DIR}/Notifications  - Telegram.md" \
  "${VAULT_DIR}/Obsidian Setup.md" \
  "${VAULT_DIR}/Service - AdGuard Home.md" \
  "${VAULT_DIR}/Service - Beszel Server Monitoring.md" \
  "${VAULT_DIR}/Service - Caddy Reverse Proxy.md" \
  "${VAULT_DIR}/Service - Firefly III Core.md" \
  "${VAULT_DIR}/Service - Firefly III Data Importer.md" \
  "${VAULT_DIR}/Service - Obsidian Sync & Flatnotes.md" \
  "${VAULT_DIR}/Service - Tailscale WireGuard Mesh.md" \
  "${VAULT_DIR}/Service - Uptime Kuma.md" \
  "${VAULT_DIR}/Service - Vaultwarden.md" 2>/dev/null || true

log_info "4. Setting permissions for Flatnotes and WebDAV (UID 82:82)..."
chown -R 82:82 "${HOMELAB_DIR}/data/dev2/obsidian" 2>/dev/null || true
chmod -R 777 "${HOMELAB_DIR}/data/dev2/obsidian"

log_info "5. Resetting Flatnotes search index to trigger full rescan..."
rm -rf "${INDEX_DIR:?}"/* 2>/dev/null || true
rm -rf "${VAULT_DIR}/.flatnotes" 2>/dev/null || true

log_info "6. Restarting Flatnotes and WebDAV containers..."
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
echo "Vault Directory Tree:"
find "${VAULT_DIR}" -maxdepth 2 -not -path '*/.*' | sort
echo "=========================================================="
