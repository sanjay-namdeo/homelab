#!/usr/bin/env bash
# ==============================================================================
# Homelab Stack Health & Security Diagnostic Tool
# ==============================================================================
# Performs end-to-end operational, security, and resource checks.
# ==============================================================================

set -euo pipefail

HOMELAB_DIR="/opt/homelab"
cd "${HOMELAB_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { echo -e "  [${GREEN}✔ PASS${NC}] $1"; }
warn() { echo -e "  [${YELLOW}⚠ WARN${NC}] $1"; }
fail() { echo -e "  [${RED}✖ FAIL${NC}] $1"; }
header() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

echo "=========================================================="
echo " Starting Homelab Stack Health & Diagnostic Check"
echo "=========================================================="

# ------------------------------------------------------------------------------
# 1. Tailscale Status
# ------------------------------------------------------------------------------
header "1. Tailscale Network Mesh"
if command -v tailscale &>/dev/null; then
    TS_STATUS=$(tailscale status --json 2>/dev/null || echo "{}")
    TS_RUNNING=$(echo "${TS_STATUS}" | jq -r '.BackendState // empty')
    
    if [[ "${TS_RUNNING}" == "Running" ]]; then
        TS_IP=$(tailscale ip -4 2>/dev/null || echo "Unknown")
        TS_FQDN=$(echo "${TS_STATUS}" | jq -r '.Self.DNSName // empty' | sed 's/\.$//')
        pass "Tailscale is connected and active"
        echo "      Node IP  : ${TS_IP}"
        echo "      Tailnet  : ${TS_FQDN}"
    else
        fail "Tailscale is not connected (State: ${TS_RUNNING})"
    fi
else
    fail "Tailscale CLI is not installed"
fi

# ------------------------------------------------------------------------------
# 2. Docker Container Services
# ------------------------------------------------------------------------------
header "2. Container Service Health"
CONTAINERS=("vaultwarden" "adguardhome" "caddy")
for c in "${CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${c}$"; then
        STATUS=$(docker inspect --format='{{.State.Status}}' "${c}" 2>/dev/null || echo "unknown")
        pass "Container '${c}' is running (${STATUS})"
    else
        fail "Container '${c}' is NOT running"
    fi
done

# ------------------------------------------------------------------------------
# 3. Functional & Endpoint Verification
# ------------------------------------------------------------------------------
header "3. Functional & Endpoint Verification"

# Vaultwarden HTTPS
TS_FQDN=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' | sed 's/\.$//' || echo "")
if [[ -n "${TS_FQDN}" ]]; then
    HTTP_CODE=$(curl -s -k -o /dev/null -w "%{http_code}" "https://${TS_FQDN}/alive" 2>/dev/null || echo "000")
    if [[ "${HTTP_CODE}" == "200" ]]; then
        pass "Vaultwarden HTTPS is responding (https://${TS_FQDN} -> HTTP 200 OK)"
    else
        warn "Vaultwarden HTTPS returned status code ${HTTP_CODE}"
    fi
fi

# AdGuard Home DNS
TS_IP=$(tailscale ip -4 2>/dev/null || echo "127.0.0.1")
if dig @"${TS_IP}" google.com +short +time=2 &>/dev/null; then
    pass "AdGuard Home DNS is resolving queries via Tailscale IP (${TS_IP}:53)"
else
    fail "AdGuard Home DNS resolution failed on ${TS_IP}:53"
fi

# AdGuard Home Web UI
AG_HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://${TS_IP}:8081/login.html" 2>/dev/null || echo "000")
if [[ "${AG_HTTP}" == "200" ]]; then
    pass "AdGuard Home Web UI is reachable (http://${TS_IP}:8081 -> HTTP 200 OK)"
else
    warn "AdGuard Home Web UI returned status code ${AG_HTTP}"
fi

# Caddy HTTP Redirect
CADDY_REDIR=$(curl -s -I "http://127.0.0.1/" 2>/dev/null | grep -i "Location:" || echo "")
if [[ "${CADDY_REDIR}" =~ "https://" ]]; then
    pass "Caddy HTTP-to-HTTPS redirect is active (${CADDY_REDIR//[$'\t\r\n']/})"
else
    warn "Caddy redirect check did not return expected HTTPS location header"
fi

# ------------------------------------------------------------------------------
# 4. Security & Network Isolation Checks
# ------------------------------------------------------------------------------
header "4. Security & Isolation State"

# WAN Port Blocking Test (ens3 interface)
LAN_IP=$(ip -4 addr show ens3 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 || echo "")
if [[ -n "${LAN_IP}" ]]; then
    if ! nc -z -w 1 "${LAN_IP}" 8081 2>/dev/null; then
        pass "Port 8081 is closed on WAN/LAN interface (${LAN_IP}) - Secure"
    else
        fail "Port 8081 is accessible on WAN/LAN interface (${LAN_IP})!"
    fi

    if ! nc -z -w 1 "${LAN_IP}" 53 2>/dev/null; then
        pass "Port 53 is closed on WAN/LAN interface (${LAN_IP}) - Secure"
    else
        fail "Port 53 is accessible on WAN/LAN interface (${LAN_IP})!"
    fi
fi

# File permissions check
VW_PERMS=$(stat -c "%a" "${HOMELAB_DIR}/data/vaultwarden" 2>/dev/null || echo "")
if [[ "${VW_PERMS}" == "700" ]]; then
    pass "Vaultwarden data directory permissions are strictly locked (0700)"
else
    warn "Vaultwarden data directory permissions: ${VW_PERMS} (recommended: 0700)"
fi

# ------------------------------------------------------------------------------
# 5. Host Resource Consumption
# ------------------------------------------------------------------------------
header "5. System Resource Utilization"
RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')
RAM_USED=$(free -h | awk '/Mem:/ {print $3}')
SWAP_TOTAL=$(free -h | awk '/Swap:/ {print $2}')
SWAP_USED=$(free -h | awk '/Swap:/ {print $3}')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
DISK_USE=$(df -h / | awk 'NR==2 {print $5}')

echo "  Memory : ${RAM_USED} used / ${RAM_TOTAL} total"
echo "  Swap   : ${SWAP_USED} used / ${SWAP_TOTAL} total"
echo "  Disk   : ${DISK_USE} used (${DISK_AVAIL} available)"

echo ""
echo "=========================================================="
echo -e "${GREEN} Diagnostic Check Complete!${NC}"
echo "=========================================================="
