#!/usr/bin/env bash
# ==============================================================================
# Homelab Complete Rollback & Cleanup Script
# ==============================================================================
set -euo pipefail

echo "============================================================"
echo " Starting Full Homelab Teardown & Reversion..."
echo "============================================================"

# 1. Stop and remove all running containers and networks
if command -v docker &>/dev/null && [ -f /opt/homelab/docker-compose.yml ]; then
    echo "[1/6] Stopping and tearing down Docker containers & volumes..."
    docker compose -f /opt/homelab/docker-compose.yml down -v --remove-orphans || true
fi

# 2. Disconnect and remove Tailscale
echo "[2/6] Disconnecting and purging Tailscale..."
sudo tailscale down 2>/dev/null || true
sudo systemctl stop tailscaled 2>/dev/null || true
sudo systemctl disable tailscaled 2>/dev/null || true
sudo apt-get purge -y tailscale 2>/dev/null || true
sudo rm -rf /var/lib/tailscale /usr/share/keyrings/tailscale-archive-keyring.gpg /etc/apt/sources.list.d/tailscale.list

# 3. Restore systemd-resolved and DNS stub configuration
echo "[3/6] Restoring systemd-resolved to Ubuntu default..."
sudo rm -f /etc/systemd/resolved.conf.d/adguard.conf
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo systemctl restart systemd-resolved

# 4. Revert sysctl kernel parameters
echo "[4/6] Restoring kernel sysctl parameters..."
sudo rm -f /etc/sysctl.d/99-homelab.conf
sudo sysctl --system >/dev/null 2>&1 || true

# 5. Remove Docker Engine & Compose packages
echo "[5/6] Removing Docker packages & cleaning apt cache..."
sudo systemctl stop docker containerd 2>/dev/null || true
sudo systemctl disable docker containerd 2>/dev/null || true
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras 2>/dev/null || true
sudo apt-get autoremove -y --purge
sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker /etc/apt/keyrings/docker.gpg /etc/apt/sources.list.d/docker.list

# 6. Delete all homelab directories and data
echo "[6/6] Removing /opt/homelab directory..."
sudo rm -rf /opt/homelab

echo "============================================================"
echo " ✅ Rollback complete! Server restored to pristine baseline."
echo "============================================================"
