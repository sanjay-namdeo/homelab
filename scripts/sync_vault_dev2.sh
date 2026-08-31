#!/usr/bin/env bash
# ==============================================================================
# Homelab: Bidirectional Vault Sync between dev2 (Flatnotes) and dev1 (WebDAV)
# ==============================================================================
# Keeps the local Flatnotes vault on dev2 synchronized with the primary Obsidian
# WebDAV server on dev1 over Tailscale mesh TLS.
# ==============================================================================

set -euo pipefail

export PATH="/home/sanjay-namdeo/.local/bin:/usr/local/bin:$PATH"

VAULT_DIR="/opt/homelab/data/dev2/obsidian/vault"
WEBDAV_URL="https://dev1.tail256d6d.ts.net:8082/data/"
WEBDAV_USER="${WEBDAV_USERNAME:-obsidian}"
WEBDAV_PASS="${WEBDAV_PASSWORD:-ooWQsB8jPwIjbpeG}"

# Obscure password for rclone
RCLONE_PASS=$(rclone obscure "${WEBDAV_PASS}")

mkdir -p "${VAULT_DIR}"

# Synchronize from dev1 WebDAV to dev2 Flatnotes vault (download new/updated notes)
rclone sync \
    --webdav-url "${WEBDAV_URL}" \
    --webdav-user "${WEBDAV_USER}" \
    --webdav-pass "${RCLONE_PASS}" \
    --webdav-vendor other \
    --exclude ".flatnotes/**" \
    --exclude "*_WRITELOCK*" \
    --exclude ".obsidian/workspace*" \
    --exclude ".trash/**" \
    --update \
    :webdav: "${VAULT_DIR}" 2>/dev/null || true

# Synchronize any local Flatnotes changes back to dev1 WebDAV (upload newly written notes)
rclone sync \
    --webdav-url "${WEBDAV_URL}" \
    --webdav-user "${WEBDAV_USER}" \
    --webdav-pass "${RCLONE_PASS}" \
    --webdav-vendor other \
    --exclude ".flatnotes/**" \
    --exclude "*_WRITELOCK*" \
    --exclude ".obsidian/workspace*" \
    --exclude ".trash/**" \
    --update \
    "${VAULT_DIR}" :webdav: 2>/dev/null || true

# Maintain proper permissions for Flatnotes container (UID 82:82)
chown -R 82:82 /opt/homelab/data/dev2/obsidian 2>/dev/null || true
chmod -R 777 /opt/homelab/data/dev2/obsidian 2>/dev/null || true
