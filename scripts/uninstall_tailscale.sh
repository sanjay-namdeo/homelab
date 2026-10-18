#!/usr/bin/env bash
# ==============================================================================
# Tailscale Complete Uninstall & Cleanup Script
# ==============================================================================
# Completely uninstalls Tailscale, tears down virtual interfaces, purges packages,
# and wipes residual state directories, apt sources, and GPG keyrings.
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

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root or with sudo:"
    echo "  sudo $0"
    exit 1
fi

echo "============================================================"
echo " Starting Tailscale Complete Uninstall & Cleanup..."
echo "============================================================"

# 1. Disconnect Tailscale session
log_info "[1/5] Disconnecting active Tailscale session..."
if command -v tailscale &>/dev/null; then
    tailscale down 2>/dev/null || true
    log_success "Tailscale session disconnected."
else
    log_info "Tailscale binary not found; skipping session disconnect."
fi

# 2. Stop and disable systemd daemon
log_info "[2/5] Stopping and disabling Tailscale systemd services..."
systemctl stop tailscaled tailscale-wait-online.service 2>/dev/null || true
systemctl disable tailscaled tailscale-wait-online.service 2>/dev/null || true
log_success "Tailscale services stopped and disabled."

# 3. Purge apt packages
log_info "[3/5] Purging Tailscale packages..."
apt-get purge -y tailscale tailscale-archive-keyring 2>/dev/null || true
apt-get autoremove -y --purge 2>/dev/null || true
log_success "Tailscale packages purged."

# 4. Remove residual configuration, state files, and apt sources
log_info "[4/5] Removing residual directories, state, and keyrings..."
rm -rf /var/lib/tailscale \
       /etc/default/tailscaled \
       /usr/share/keyrings/tailscale-archive-keyring.gpg \
       /etc/apt/sources.list.d/tailscale.list
log_success "Residual configuration and state files removed."

# 5. Remove virtual network interface
log_info "[5/5] Removing tailscale0 virtual network interface..."
if ip link show tailscale0 &>/dev/null; then
    ip link delete tailscale0 2>/dev/null || true
    log_success "tailscale0 interface removed."
else
    log_info "No tailscale0 network interface found."
fi

echo "============================================================"
echo -e "${GREEN} ✅ Tailscale has been completely uninstalled!${NC}"
echo "============================================================"
