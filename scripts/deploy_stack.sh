#!/usr/bin/env bash
# ==============================================================================
# Homelab Stack Deployment & Automation Script (Multi-Host: dev1 & dev2)
# ==============================================================================
# Sets up host prerequisites, installs Docker & Tailscale (if missing),
# provisions stack secrets & storage, and launches container services.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# Detect or specify target host
TARGET_HOST=""
if [[ $# -gt 0 ]]; then
    case "$1" in
        --host|-h)
            TARGET_HOST="$2"
            shift 2
            ;;
        dev1|dev2)
            TARGET_HOST="$1"
            shift 1
            ;;
    esac
fi

if [[ -z "${TARGET_HOST}" ]]; then
    HOSTNAME_S=$(hostname -s 2>/dev/null || echo "")
    if [[ "${HOSTNAME_S}" == "dev2" ]]; then
        TARGET_HOST="dev2"
    else
        TARGET_HOST="dev1"
    fi
fi

echo "=========================================================="
echo " Starting Homelab Stack Automated Deployment (${TARGET_HOST})"
echo "=========================================================="

# ------------------------------------------------------------------------------
# 1. Host Tuning & Kernel Forwarding
# ------------------------------------------------------------------------------
log_info "[1/6] Applying Kernel Sysctl optimizations..."
cat > /etc/sysctl.d/99-homelab.conf << 'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
vm.swappiness = 15
vm.vfs_cache_pressure = 50
EOF
sysctl --system >/dev/null 2>&1 || true
log_success "Sysctl optimizations applied."

# ------------------------------------------------------------------------------
# 2. Host-specific DNS adjustments
# ------------------------------------------------------------------------------
if [[ "${TARGET_HOST}" == "dev1" ]]; then
    log_info "[2/6] Configuring systemd-resolved DNSStubListener=no for AdGuard..."
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
    log_success "systemd-resolved configured for port 53."
else
    log_info "[2/6] Skipping Port 53 DNS stub listener bypass (not required for dev2)."
fi

# ------------------------------------------------------------------------------
# 3. Install Docker Engine & Compose (if not present)
# ------------------------------------------------------------------------------
if ! command -v docker &>/dev/null; then
    log_info "[3/6] Installing Docker Engine & Compose..."
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
    log_info "[3/6] Docker Engine is already installed."
fi

# ------------------------------------------------------------------------------
# 4. Install & Check Tailscale
# ------------------------------------------------------------------------------
if ! command -v tailscale &>/dev/null; then
    log_info "[4/6] Installing Tailscale..."
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(. /etc/os-release && echo "$VERSION_CODENAME").noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(. /etc/os-release && echo "$VERSION_CODENAME").tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
    apt-get update -y
    apt-get install -y tailscale
    systemctl enable --now tailscaled
fi

log_info "Checking Tailscale connection..."
if ! tailscale status &>/dev/null; then
    log_warn "Tailscale is not authenticated. Starting tailscale up..."
    tailscale up --ssh
fi

TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
TS_FQDN=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName' 2>/dev/null | sed 's/\.$//' || echo "")
log_success "Tailscale connected: IP=${TS_IP:-unknown}, FQDN=${TS_FQDN:-unknown}"

# ------------------------------------------------------------------------------
# 5. Prepare Data Directories & Environment Secrets
# ------------------------------------------------------------------------------
log_info "[5/6] Preparing data directories and secrets..."

if [[ "${TARGET_HOST}" == "dev2" ]]; then
    mkdir -p "${HOMELAB_DIR}/data/dev2/obsidian/vault"
    mkdir -p "${HOMELAB_DIR}/data/dev2/obsidian/flatnotes_data"
    mkdir -p "${HOMELAB_DIR}/data/dev2/beszel/data"
    mkdir -p "${HOMELAB_DIR}/data/dev2/beszel/socket"
    if [[ -d "${HOMELAB_DIR}/notes" ]]; then
        cp -n "${HOMELAB_DIR}/notes"/*.md "${HOMELAB_DIR}/data/dev2/obsidian/vault/" 2>/dev/null || true
    fi
    chown -R 82:82 "${HOMELAB_DIR}/data/dev2/obsidian" 2>/dev/null || true
    chmod -R 775 "${HOMELAB_DIR}/data/dev2/obsidian" 2>/dev/null || true
    mkdir -p "${HOMELAB_DIR}/hosts/dev2"

    DEV2_ENV="${HOMELAB_DIR}/hosts/dev2/.env"
    if [[ ! -f "${DEV2_ENV}" ]]; then
        log_info "Generating secure secrets for dev2 .env..."
        DAV_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
        FLAT_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
        FLAT_KEY=$(openssl rand -hex 32)
        cat > "${DEV2_ENV}" << EOF
# Environment Configuration (dev2)
TZ=Asia/Kolkata

# Obsidian WebDAV Sync & Flatnotes Web Editor
WEBDAV_USERNAME=obsidian
WEBDAV_PASSWORD=${DAV_PASS}

FLATNOTES_AUTH_TYPE=password
FLATNOTES_USERNAME=obsidian
FLATNOTES_PASSWORD=${FLAT_PASS}
FLATNOTES_SECRET_KEY=${FLAT_KEY}

# Beszel Server Health Hub & Agent
BESZEL_KEY=
EOF
        chmod 600 "${DEV2_ENV}"
        log_success "Generated ${DEV2_ENV} (chmod 600)."
    fi

    # 6. Launch dev2 stack & configure Tailscale Serve
    log_info "[6/6] Launching dev2 Docker stack..."
    docker compose -f "${HOMELAB_DIR}/hosts/dev2/docker-compose.yml" up -d
    log_success "dev2 Docker stack started."

    log_info "Configuring Tailscale Serve for HTTPS termination..."
    tailscale serve --bg --https=8082 http://127.0.0.1:8082 2>/dev/null || true
    tailscale serve --bg --https=8083 http://127.0.0.1:8083 2>/dev/null || true
    tailscale serve --bg --https=8090 http://127.0.0.1:8090 2>/dev/null || true
    log_success "Tailscale Serve configured (8082 -> WebDAV, 8083 -> Flatnotes, 8090 -> Beszel Hub)."

    echo ""
    echo "=========================================================="
    echo -e "${GREEN} dev2 Homelab Stack Deployed Successfully!${NC}"
    echo "=========================================================="
    echo " - Obsidian WebDAV Sync:   https://${TS_FQDN:-<your-tailscale-fqdn>}:8082/data/"
    echo " - Obsidian Web Editor:    https://${TS_FQDN:-<your-tailscale-fqdn>}:8083"
    echo " - Beszel Health Hub:      https://${TS_FQDN:-<your-tailscale-fqdn>}:8090"
    echo "=========================================================="

else
    mkdir -p "${HOMELAB_DIR}/data/vaultwarden"
    mkdir -p "${HOMELAB_DIR}/data/adguard/work"
    mkdir -p "${HOMELAB_DIR}/data/adguard/conf"
    mkdir -p "${HOMELAB_DIR}/data/caddy/data"
    mkdir -p "${HOMELAB_DIR}/data/caddy/config"
    mkdir -p "${HOMELAB_DIR}/data/uptime-kuma"

    if [ ! -f "${HOMELAB_DIR}/.env" ]; then
        if [ -f "${HOMELAB_DIR}/.env.example" ]; then
            cp "${HOMELAB_DIR}/.env.example" "${HOMELAB_DIR}/.env"
        elif [ -f "${HOMELAB_DIR}/hosts/dev1/.env.example" ]; then
            cp "${HOMELAB_DIR}/hosts/dev1/.env.example" "${HOMELAB_DIR}/.env"
        else
            cat > "${HOMELAB_DIR}/.env" << 'EOF'
TZ=UTC
SIGNUPS_ALLOWED=true
EOF
        fi
        chmod 600 "${HOMELAB_DIR}/.env"
    fi

    # Copy to hosts/dev1/.env for consistency
    mkdir -p "${HOMELAB_DIR}/hosts/dev1"
    [[ ! -f "${HOMELAB_DIR}/hosts/dev1/.env" ]] && cp "${HOMELAB_DIR}/.env" "${HOMELAB_DIR}/hosts/dev1/.env" && chmod 600 "${HOMELAB_DIR}/hosts/dev1/.env"

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

    if [ ! -f "${HOMELAB_DIR}/Caddyfile" ]; then
        cat > "${HOMELAB_DIR}/Caddyfile" << 'EOF'
{
    admin off
}

# Tailscale TLS certificate for Vaultwarden (Port 443)
{$TAILSCALE_FQDN} {
    tls {
        get_certificate tailscale
    }
    reverse_proxy vaultwarden:80
}

# Tailscale TLS certificate for AdGuard Home Web UI (Port 8081)
{$TAILSCALE_FQDN}:8081 {
    tls {
        get_certificate tailscale
    }
    reverse_proxy adguardhome:80
}

# Tailscale TLS certificate for Uptime Kuma (Port 3001)
{$TAILSCALE_FQDN}:3001 {
    tls {
        get_certificate tailscale
    }
    reverse_proxy uptime-kuma:3001
}

# Direct HTTP fallback: redirect to Tailscale HTTPS domain
:80 {
    redir https://{$TAILSCALE_FQDN}{uri} permanent
}
EOF
    fi

    # 6. Launch dev1 stack
    log_info "[6/6] Launching dev1 Docker container stack..."
    docker compose -f "${HOMELAB_DIR}/docker-compose.yml" up -d
    log_success "Docker containers started successfully!"

    echo ""
    echo "=========================================================="
    echo -e "${GREEN} dev1 Homelab Stack Deployed Successfully!${NC}"
    echo "=========================================================="
    echo "Access Information (from any device connected to Tailscale):"
    echo " - Vaultwarden:   https://${TS_FQDN:-<your-tailscale-fqdn>}"
    echo " - AdGuard Home:  https://${TS_FQDN:-<your-tailscale-fqdn>}:8081"
    echo " - Uptime Kuma:   https://${TS_FQDN:-<your-tailscale-fqdn>}:3001"
    echo "=========================================================="
fi
