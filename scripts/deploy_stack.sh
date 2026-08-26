#!/usr/bin/env bash
# ==============================================================================
# Homelab Stack Deployment & Automation Script
# ==============================================================================
# Sets up DNS stub listeners, installs Docker & Tailscale (if missing),
# detects the Tailscale MagicDNS domain, configures Caddy TLS, and starts services.
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
echo " Starting Homelab Stack Automated Deployment"
echo "=========================================================="

# ------------------------------------------------------------------------------
# 1. Configure systemd-resolved for Port 53 coexistence
# ------------------------------------------------------------------------------
log_info "[1/7] Configuring systemd-resolved DNSStubListener=no for AdGuard..."
mkdir -p /etc/systemd/resolved.conf.d/
cat > /etc/systemd/resolved.conf.d/adguard.conf << 'EOF'
[Resolve]
DNS=1.1.1.1 8.8.8.8
DNSStubListener=no
EOF

if [ -f /run/systemd/resolve/resolv.conf ]; then
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
fi
systemctl restart systemd-resolved || true
log_success "systemd-resolved configured."

# ------------------------------------------------------------------------------
# 2. Enable Kernel IP Forwarding (for Tailscale Exit Node)
# ------------------------------------------------------------------------------
log_info "[2/7] Ensuring Kernel IP Forwarding is active..."
cat > /etc/sysctl.d/99-homelab.conf << 'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
vm.swappiness = 15
vm.vfs_cache_pressure = 50
EOF
sysctl --system >/dev/null 2>&1 || true
log_success "IP Forwarding enabled."

# ------------------------------------------------------------------------------
# 3. Install Docker Engine & Compose (if not present)
# ------------------------------------------------------------------------------
if ! command -v docker &>/dev/null; then
    log_info "[3/7] Installing Docker Engine & Compose..."
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    log_success "Docker Engine installed."
else
    log_info "[3/7] Docker Engine is already installed."
fi

# ------------------------------------------------------------------------------
# 4. Install & Check Tailscale
# ------------------------------------------------------------------------------
if ! command -v tailscale &>/dev/null; then
    log_info "[4/7] Installing Tailscale..."
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(. /etc/os-release && echo "$VERSION_CODENAME").noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(. /etc/os-release && echo "$VERSION_CODENAME").tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
    apt-get update -y
    apt-get install -y tailscale
    systemctl enable --now tailscaled
fi

# Check Tailscale auth status
log_info "Checking Tailscale connection..."
if ! tailscale status &>/dev/null; then
    log_warn "Tailscale is not authenticated. Starting tailscale up..."
    tailscale up --advertise-exit-node --ssh
fi

TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
TS_FQDN=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName' 2>/dev/null | sed 's/\.$//' || echo "")

log_success "Tailscale connected: IP=${TS_IP:-unknown}, FQDN=${TS_FQDN:-unknown}"

# ------------------------------------------------------------------------------
# 5. Create Persistent Data Directories & Environment (.env)
# ------------------------------------------------------------------------------
log_info "[5/7] Preparing directory structure and .env..."
mkdir -p "${HOMELAB_DIR}/data/vaultwarden"
mkdir -p "${HOMELAB_DIR}/data/adguard/work"
mkdir -p "${HOMELAB_DIR}/data/adguard/conf"
mkdir -p "${HOMELAB_DIR}/data/caddy/data"
mkdir -p "${HOMELAB_DIR}/data/caddy/config"

if [ ! -f "${HOMELAB_DIR}/.env" ]; then
    if [ -f "${HOMELAB_DIR}/.env.example" ]; then
        cp "${HOMELAB_DIR}/.env.example" "${HOMELAB_DIR}/.env"
    else
        cat > "${HOMELAB_DIR}/.env" << 'EOF'
TZ=UTC
SIGNUPS_ALLOWED=true
EOF
    fi
    chmod 600 "${HOMELAB_DIR}/.env"
fi

# Dynamically update Tailscale network values in .env
TS_HOSTNAME=$(echo "${TS_FQDN}" | cut -d. -f1)
TS_TAILNET=$(echo "${TS_FQDN}" | cut -d. -f2-)

update_env_var() {
    local key="$1"
    local val="$2"
    if grep -q "^${key}=" "${HOMELAB_DIR}/.env"; then
        sed -i "s|^${key}=.*|${key}=${val}|" "${HOMELAB_DIR}/.env"
    else
        echo "${key}=${val}" >> "${HOMELAB_DIR}/.env"
    fi
}

[[ -n "${TS_IP}" ]] && update_env_var "TAILSCALE_IP" "${TS_IP}"
[[ -n "${TS_HOSTNAME}" ]] && update_env_var "TAILSCALE_HOSTNAME" "${TS_HOSTNAME}"
[[ -n "${TS_TAILNET}" ]] && update_env_var "TAILNET_NAME" "${TS_TAILNET}"
[[ -n "${TS_FQDN}" ]] && update_env_var "TAILSCALE_FQDN" "${TS_FQDN}"

# ------------------------------------------------------------------------------
# 6. Ensure Caddyfile is Configured
# ------------------------------------------------------------------------------
log_info "[6/7] Ensuring Caddyfile is present..."
if [ ! -f "${HOMELAB_DIR}/Caddyfile" ]; then
    cat > "${HOMELAB_DIR}/Caddyfile" << 'EOF'
{
    admin off
}

# Tailscale TLS certificate for Vaultwarden
{$TAILSCALE_FQDN} {
    tls {
        get_certificate tailscale
    }
    reverse_proxy vaultwarden:80
}

# Direct HTTP fallback: redirect to Tailscale HTTPS domain
:80 {
    redir https://{$TAILSCALE_FQDN}{uri} permanent
}
EOF
fi
log_success "Caddyfile configured."

# ------------------------------------------------------------------------------
# 7. Start Docker Stack
# ------------------------------------------------------------------------------
log_info "[7/7] Launching Docker container stack..."
docker compose -f "${HOMELAB_DIR}/docker-compose.yml" up -d
log_success "Docker containers started successfully!"

echo ""
echo "=========================================================="
echo -e "${GREEN} Homelab Stack Deployed Successfully!${NC}"
echo "=========================================================="
echo ""
echo "Access Information (from any device connected to Tailscale):"
echo " - Vaultwarden:   https://${TS_FQDN:-<your-tailscale-fqdn>}"
echo " - AdGuard Home:  http://${TS_IP:-<your-tailscale-ip>}:8081 (Initial Setup: http://${TS_IP:-<tailscale-ip>}:3000)"
echo ""
