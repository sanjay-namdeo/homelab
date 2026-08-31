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

# Configure Docker daemon log rotation
if [ ! -f /etc/docker/daemon.json ]; then
    log_info "Configuring Docker daemon log limits (10MB x 3)..."
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    systemctl reload docker 2>/dev/null || systemctl restart docker
fi

# Configure ZRAM in-memory compressed swap
if ! dpkg -l | grep -q "systemd-zram-generator"; then
    log_info "Configuring ZRAM in-memory compressed swap..."
    apt-get install -y systemd-zram-generator 2>/dev/null || true
    cat > /etc/systemd/zram-generator.conf << 'EOF'
[zram0]
zram-size = min(ram / 2, 2048)
compression-algorithm = zstd
swap-priority = 100
EOF
    systemctl daemon-reload
    systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || true
fi

# Configure Automated Daily Backup Systemd Timer
if [ ! -f /etc/systemd/system/homelab-backup.timer ]; then
    log_info "Configuring automated daily backup systemd timer..."
    cat > /etc/systemd/system/homelab-backup.service << 'EOF'
[Unit]
Description=Homelab Daily Automated Backup & Off-Site Sync
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=/opt/homelab
ExecStart=/bin/bash /opt/homelab/scripts/backup_homelab.sh
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/homelab-backup.timer << 'EOF'
[Unit]
Description=Run Homelab Daily Backup at 3:00 AM UTC
Persistent=true

[Timer]
OnCalendar=*-*-* 03:00:00
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now homelab-backup.timer
    log_success "Automated daily backup timer enabled (03:00 UTC)."
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
    mkdir -p "${HOMELAB_DIR}/data/dev2/gatus"
    mkdir -p "${HOMELAB_DIR}/hosts/dev2/gatus"
    if [[ -d "${HOMELAB_DIR}/notes" ]]; then
        cp -n "${HOMELAB_DIR}/notes"/*.md "${HOMELAB_DIR}/data/dev2/obsidian/vault/" 2>/dev/null || true
    fi
    chown -R 82:82 "${HOMELAB_DIR}/data/dev2/obsidian" 2>/dev/null || true
    chmod -R 775 "${HOMELAB_DIR}/data/dev2/obsidian" 2>/dev/null || true
    mkdir -p "${HOMELAB_DIR}/hosts/dev2"

    ROOT_ENV="${HOMELAB_DIR}/.env"
    if [[ ! -f "${ROOT_ENV}" ]]; then
        log_info "Generating secure secrets for root .env..."
        DAV_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
        FLAT_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
        FLAT_KEY=$(openssl rand -hex 32)
        DAV_AUTH=$(echo -n "obsidian:${DAV_PASS}" | base64)
        cat > "${ROOT_ENV}" << EOF
# ==============================================================================
# Homelab Environment Configuration — Single Source of Truth
# ==============================================================================
# All hosts (dev1, dev2) and all scripts source this single file.
# hosts/dev1/.env and hosts/dev2/.env are symlinks to this file.
# ==============================================================================
TZ=Asia/Kolkata

# Vaultwarden
SIGNUPS_ALLOWED=true
INVITATIONS_ALLOWED=false
WEBSOCKET_ENABLED=true

# Tailscale Multi-Host Network Settings
DEV1_TAILSCALE_IP=${DEV1_TAILSCALE_IP:-}
DEV1_TAILSCALE_FQDN=${DEV1_TAILSCALE_FQDN:-dev1.yourtailnet.ts.net}
DEV2_TAILSCALE_IP=${DEV2_TAILSCALE_IP:-127.0.0.1}
DEV2_TAILSCALE_FQDN=${DEV2_TAILSCALE_FQDN:-dev2.yourtailnet.ts.net}

# SMTP Configuration (Brevo — shared by Vaultwarden and Gatus)
SMTP_HOST=smtp-relay.brevo.com
SMTP_PORT=587
SMTP_SECURITY=starttls
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM=
SMTP_FROM_NAME=Homelab
SMTP_TIMEOUT=15
SMTP_AUTH_MECHANISM=Plain
ALERT_EMAIL=

# Obsidian WebDAV (dev1) & Flatnotes (dev2)
WEBDAV_USERNAME=obsidian
WEBDAV_PASSWORD=${DAV_PASS}
WEBDAV_BASIC_AUTH=${DAV_AUTH}

FLATNOTES_AUTH_TYPE=password
FLATNOTES_USERNAME=obsidian
FLATNOTES_PASSWORD=${FLAT_PASS}
FLATNOTES_SECRET_KEY=${FLAT_KEY}

# Beszel Server Monitoring
BESZEL_KEY=

# Cloudflare R2 Encrypted Off-Site Backup
R2_ACCOUNT_ID=
R2_BUCKET_NAME=homelab
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
BACKUP_ENCRYPTION_KEY=
EOF
        chmod 600 "${ROOT_ENV}"
        log_success "Generated ${ROOT_ENV} (chmod 600)."
    fi
    # Ensure host symlinks point to root .env
    ln -sf "${HOMELAB_DIR}/.env" "${HOMELAB_DIR}/hosts/dev2/.env" 2>/dev/null || true

    update_env_var() {
        local key="$1"
        local val="$2"
        if grep -q "^${key}=" "${HOMELAB_DIR}/.env"; then
            sed -i "s|^${key}=.*|${key}=${val}|" "${HOMELAB_DIR}/.env"
        else
            echo "${key}=${val}" >> "${HOMELAB_DIR}/.env"
        fi
    }
    [[ -n "${TS_IP}" ]] && update_env_var "DEV2_TAILSCALE_IP" "${TS_IP}"
    [[ -n "${TS_FQDN}" ]] && update_env_var "DEV2_TAILSCALE_FQDN" "${TS_FQDN}"

    # 6. Launch dev2 stack & configure Tailscale Serve
    log_info "[6/6] Launching dev2 Docker stack..."
    docker compose -p dev2 -f "${HOMELAB_DIR}/hosts/dev2/docker-compose.yml" up -d --remove-orphans
    log_success "dev2 Docker stack started."

    log_info "Configuring Tailscale Serve for HTTPS termination..."
    tailscale serve --https=8082 off 2>/dev/null || true
    tailscale serve --bg --https=8083 http://127.0.0.1:8083 2>/dev/null || true
    tailscale serve --bg --https=8085 http://127.0.0.1:8085 2>/dev/null || true
    tailscale serve --bg --https=8090 http://127.0.0.1:8090 2>/dev/null || true
    log_success "Tailscale Serve configured (8083 -> Flatnotes, 8085 -> Gatus, 8090 -> Beszel Hub)."

    echo ""
    echo "=========================================================="
    echo -e "${GREEN} dev2 Homelab Stack Deployed Successfully!${NC}"
    echo "=========================================================="
    echo " - Obsidian Web Editor:    https://${TS_FQDN:-<your-tailscale-fqdn>}:8083"
    echo " - Gatus Status Dashboard: https://${TS_FQDN:-<your-tailscale-fqdn>}:8085"
    echo " - Beszel Health Hub:      https://${TS_FQDN:-<your-tailscale-fqdn>}:8090"
    echo "=========================================================="

else
    mkdir -p "${HOMELAB_DIR}/data/vaultwarden"
    mkdir -p "${HOMELAB_DIR}/data/adguard/work"
    mkdir -p "${HOMELAB_DIR}/data/adguard/conf"
    mkdir -p "${HOMELAB_DIR}/data/caddy/data"
    mkdir -p "${HOMELAB_DIR}/data/caddy/config"
    mkdir -p "${HOMELAB_DIR}/data/obsidian/vault"

    chown -R 82:82 "${HOMELAB_DIR}/data/obsidian" 2>/dev/null || true
    chmod -R 775 "${HOMELAB_DIR}/data/obsidian" 2>/dev/null || true

    if [ ! -f "${HOMELAB_DIR}/.env" ]; then
        if [ -f "${HOMELAB_DIR}/.env.example" ]; then
            cp "${HOMELAB_DIR}/.env.example" "${HOMELAB_DIR}/.env"
        elif [ -f "${HOMELAB_DIR}/hosts/dev1/.env.example" ]; then
            cp "${HOMELAB_DIR}/hosts/dev1/.env.example" "${HOMELAB_DIR}/.env"
        else
            cat > "${HOMELAB_DIR}/.env" << 'EOF'
TZ=Asia/Kolkata
SIGNUPS_ALLOWED=true
EOF
        fi
        chmod 600 "${HOMELAB_DIR}/.env"
    fi

    # Ensure hosts/dev1/.env is a symlink to root .env
    mkdir -p "${HOMELAB_DIR}/hosts/dev1"
    ln -sf "${HOMELAB_DIR}/.env" "${HOMELAB_DIR}/hosts/dev1/.env" 2>/dev/null || true

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

    [[ -n "${TS_IP}" ]] && update_env_var "DEV1_TAILSCALE_IP" "${TS_IP}"
    [[ -n "${TS_FQDN}" ]] && update_env_var "DEV1_TAILSCALE_FQDN" "${TS_FQDN}"

    if [ ! -f "${HOMELAB_DIR}/Caddyfile" ]; then
        cat > "${HOMELAB_DIR}/Caddyfile" << 'EOF'
{
    admin off
}

# Tailscale TLS certificate for Vaultwarden (Port 443)
{$DEV1_TAILSCALE_FQDN} {
    tls {
        get_certificate tailscale
    }
    reverse_proxy vaultwarden:80
}

# Tailscale TLS certificate for AdGuard Home Web UI (Port 8081)
{$DEV1_TAILSCALE_FQDN}:8081 {
    tls {
        get_certificate tailscale
    }
    reverse_proxy adguardhome:80
}

# Tailscale TLS certificate for Obsidian WebDAV (Port 8082)
{$DEV1_TAILSCALE_FQDN}:8082 {
    tls {
        get_certificate tailscale
    }
    reverse_proxy obsidian_webdav:80
}

# Direct HTTP fallback: redirect to Tailscale HTTPS domain
:80 {
    redir https://{$DEV1_TAILSCALE_FQDN}{uri} permanent
}
EOF
    fi

    # 6. Launch dev1 stack
    log_info "[6/6] Launching dev1 Docker container stack..."
    docker compose -p homelab -f "${HOMELAB_DIR}/hosts/dev1/docker-compose.yml" up -d --remove-orphans
    log_success "Docker containers started successfully!"

    echo ""
    echo "=========================================================="
    echo -e "${GREEN} dev1 Homelab Stack Deployed Successfully!${NC}"
    echo "=========================================================="
    echo "Access Information (from any device connected to Tailscale):"
    echo " - Vaultwarden:        https://${TS_FQDN:-<your-tailscale-fqdn>}"
    echo " - AdGuard Home:       https://${TS_FQDN:-<your-tailscale-fqdn>}:8081"
    echo " - Obsidian WebDAV:    https://${TS_FQDN:-<your-tailscale-fqdn>}:8082/data/"
    echo "=========================================================="
fi
