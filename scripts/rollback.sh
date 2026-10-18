#!/usr/bin/env bash
# ==============================================================================
# Homelab Complete Rollback & Cleanup Script
# ==============================================================================
# Cleans up Docker, containerd, Tailscale, virtual interfaces, residual iptables,
# systemd timers, and restores system DNS and sysctl parameters.
#
# Options:
#   --keep-data    Purge Docker, containerd & Tailscale, but keep /opt/homelab intact (default)
#   --purge-data   Completely remove /opt/homelab directory as well
#   -y, --yes      Non-interactive mode (skip confirmation prompts)
# ==============================================================================
set -euo pipefail

KEEP_DATA=true
ASSUME_YES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep-data)
            KEEP_DATA=true
            shift
            ;;
        --purge-data|--wipe)
            KEEP_DATA=false
            shift
            ;;
        -y|--yes)
            ASSUME_YES=true
            shift
            ;;
        -h|--help)
            echo "Usage: sudo $0 [--keep-data | --purge-data] [-y|--yes]"
            echo ""
            echo "  --keep-data   Purge packages, containers & interfaces, keep /opt/homelab (default)"
            echo "  --purge-data  Purge everything including /opt/homelab"
            echo "  -y, --yes     Skip confirmation prompt"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "============================================================"
echo " Starting Homelab Teardown & Cleanup..."
if [[ "${KEEP_DATA}" == true ]]; then
    echo " Mode: Cleanup packages, runtime & interfaces (KEEP /opt/homelab data)"
else
    echo " Mode: Full Teardown & Purge (DELETE /opt/homelab data)"
fi
echo "============================================================"

if [[ "${ASSUME_YES}" != true ]]; then
    read -r -p "Are you sure you want to proceed? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            ;;
        *)
            echo "Teardown aborted."
            exit 0
            ;;
    esac
fi

# 1. Stop and remove all running containers and networks
if command -v docker &>/dev/null; then
    echo "[1/7] Stopping and tearing down Docker containers & volumes..."
    [ -f /opt/homelab/docker-compose.yml ] && docker compose -f /opt/homelab/docker-compose.yml down -v --remove-orphans 2>/dev/null || true
    [ -f /opt/homelab/hosts/dev1/docker-compose.yml ] && docker compose -f /opt/homelab/hosts/dev1/docker-compose.yml down -v --remove-orphans 2>/dev/null || true
    [ -f /opt/homelab/hosts/dev2/docker-compose.yml ] && docker compose -f /opt/homelab/hosts/dev2/docker-compose.yml down -v --remove-orphans 2>/dev/null || true
fi

# 2. Disconnect and remove Tailscale
echo "[2/7] Disconnecting and purging Tailscale..."
sudo tailscale down 2>/dev/null || true
sudo systemctl stop tailscaled tailscale-wait-online.service 2>/dev/null || true
sudo systemctl disable tailscaled tailscale-wait-online.service 2>/dev/null || true
sudo apt-get purge -y tailscale tailscale-archive-keyring 2>/dev/null || true
sudo rm -rf /var/lib/tailscale /usr/share/keyrings/tailscale-archive-keyring.gpg /etc/apt/sources.list.d/tailscale.list
sudo ip link delete tailscale0 2>/dev/null || true

# 3. Restore systemd-resolved and DNS stub configuration
echo "[3/7] Restoring systemd-resolved to Ubuntu default..."
sudo rm -f /etc/systemd/resolved.conf.d/adguard.conf
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo systemctl restart systemd-resolved 2>/dev/null || true

# 4. Revert sysctl kernel parameters
echo "[4/7] Restoring kernel sysctl parameters..."
sudo rm -f /etc/sysctl.d/99-homelab.conf
sudo sysctl --system >/dev/null 2>&1 || true

# 5. Remove Docker Engine & Compose packages
echo "[5/7] Removing Docker packages & cleaning apt cache..."
sudo systemctl stop docker.socket docker containerd 2>/dev/null || true
sudo systemctl disable docker.socket docker containerd 2>/dev/null || true
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras 2>/dev/null || true
sudo apt-get autoremove -y --purge 2>/dev/null || true
sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker /etc/apt/keyrings/docker.gpg /etc/apt/keyrings/docker.asc /etc/apt/sources.list.d/docker.list
sudo ip link set docker0 down 2>/dev/null || true
sudo ip link delete docker0 2>/dev/null || true

# 6. Clean residual Docker iptables chains
echo "[6/7] Cleaning residual iptables chains..."
sudo iptables -D FORWARD -j DOCKER-USER 2>/dev/null || true
sudo iptables -D FORWARD -j DOCKER-FORWARD 2>/dev/null || true
sudo iptables -F DOCKER-FORWARD 2>/dev/null || true
sudo iptables -F DOCKER-BRIDGE 2>/dev/null || true
sudo iptables -F DOCKER-CT 2>/dev/null || true
sudo iptables -F DOCKER-INTERNAL 2>/dev/null || true
sudo iptables -F DOCKER 2>/dev/null || true
sudo iptables -F DOCKER-USER 2>/dev/null || true
sudo iptables -X DOCKER-FORWARD 2>/dev/null || true
sudo iptables -X DOCKER-BRIDGE 2>/dev/null || true
sudo iptables -X DOCKER 2>/dev/null || true
sudo iptables -X DOCKER-CT 2>/dev/null || true
sudo iptables -X DOCKER-INTERNAL 2>/dev/null || true
sudo iptables -X DOCKER-USER 2>/dev/null || true
sudo iptables -t nat -D PREROUTING -m addrtype --dst-type LOCAL -j DOCKER 2>/dev/null || true
sudo iptables -t nat -D OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER 2>/dev/null || true
sudo iptables -t nat -D POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE 2>/dev/null || true
sudo iptables -t nat -F DOCKER 2>/dev/null || true
sudo iptables -t nat -X DOCKER 2>/dev/null || true

# Disable homelab systemd timers
sudo systemctl stop homelab-backup.timer homelab-vault-sync.timer 2>/dev/null || true
sudo systemctl disable homelab-backup.timer homelab-vault-sync.timer 2>/dev/null || true
sudo rm -f /etc/systemd/system/homelab-backup.* /etc/systemd/system/homelab-vault-sync.* 2>/dev/null || true
sudo systemctl daemon-reload 2>/dev/null || true

# 7. Optionally delete homelab directory
if [[ "${KEEP_DATA}" == false ]]; then
    echo "[7/7] Removing /opt/homelab directory..."
    sudo rm -rf /opt/homelab
else
    echo "[7/7] Keeping /opt/homelab directory intact (configs, data, and backups preserved)."
fi

echo "============================================================"
echo " ✅ Cleanup complete! Server restored to pristine baseline."
echo "============================================================"
