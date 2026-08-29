# 🛡️ Service: AdGuard Home (Network-Wide DNS & Ad-Blocking)

**AdGuard Home** acts as a network-wide DNS sinkhole, filtering out advertisements, tracking telemetry, phishing, and malware domains before connections are established.

---

## 🏗️ Architecture & Deployment

- **Host Node:** `dev1`
- **Docker Image:** `adguard/adguardhome:latest`
- **Web Administration Port:** `127.0.0.1:8081` (Proxied via Caddy to `https://dev1.<tailnet>.ts.net:8081`)
- **DNS Server Port:** Port `53` (TCP/UDP) bound to Tailscale IP (`<dev1-tailscale-ip>:53`) and localhost (`127.0.0.1:53`)
- **Configuration & Work Data:** `/opt/homelab/data/adguard/conf` and `/opt/homelab/data/adguard/work`
- **Resource Constraints:** Max 128 MB RAM, 0.50 vCPU

```mermaid
graph TD
    Client["📱 Tailscale Mesh Clients (Laptops / Phones)"] -->|Encrypted DNS Queries (Port 53)| AG["🛡️ AdGuard Home DNS Resolver (<dev1-tailscale-ip>)"]
    AG -->|Check Blocklists & Custom Rules| Filter{"Is Domain Blocked?"}
    Filter -->|Yes (Ad/Tracker)| Sinkhole["🚫 Return 0.0.0.0 / Block Page"]
    Filter -->|No (Clean)| Upstream["🔒 Encrypted Upstream DNS (DoH/DoT)\nCloudflare / Quad9"]
    Upstream --> CleanIP["✅ Return Valid IP to Client"]
```

---

## ⚙️ Port 53 Resolution on Linux (`systemd-resolved`)

On Ubuntu servers, `systemd-resolved` by default listens on `127.0.0.53:53` as a local stub listener, preventing Docker from binding port 53.

Our deployment script automates the fix:
```bash
# Configuration written to /etc/systemd/resolved.conf.d/adguard.conf:
[Resolve]
DNS=1.1.1.1 8.8.8.8
DNSStubListener=no
```
And symlinks `/run/systemd/resolve/resolv.conf` to `/etc/resolv.conf`.

---

## 🌐 Configuring Devices to Use AdGuard Home

### 1. Mesh-Wide DNS via Tailscale MagicDNS (Recommended)
You can enforce ad-blocking on all connected laptops, tablets, and phones anywhere in the world:
1. Open the [Tailscale Admin Console](https://login.tailscale.com/admin/dns).
2. Go to **DNS** ➔ **Nameservers**.
3. Click **Add nameserver** ➔ **Custom**.
4. Enter your `dev1` Tailscale IP: `<dev1-tailscale-ip>` (or `dev1` MagicDNS IP).
5. Toggle **Override local DNS** to **ON**.
6. All traffic across your tailnet will now resolve and filter through AdGuard Home securely without exposing DNS port 53 to the public internet!

### 2. Local Wi-Fi Router / Home LAN
To block ads on home smart TVs and IoT devices not running Tailscale:
- Set your Wi-Fi router's primary DNS (LAN DHCP setting) to `dev1`'s local LAN IP.

---

## 🔒 Recommended Upstream DNS Servers

In the AdGuard Home Web UI (**Settings** ➔ **DNS Settings** ➔ **Upstream DNS servers**), configure high-performance DNS-over-HTTPS (DoH) and DNS-over-TLS (DoT) resolvers:

```text
# Cloudflare DNS over HTTPS
https://cloudflare-dns.com/dns-query

# Quad9 DNS over TLS (Malware Blocking)
tls://dns.quad9.net

# AdGuard DNS over HTTPS
https://dns.adguard-dns.com/dns-query
```

### Upstream DNS Mode
- Select **Parallel requests** for minimum latency (AdGuard queries all upstream resolvers simultaneously and returns the fastest response).

---

## 🚫 Recommended Blocklists (Filter Lists)

Navigate to **Filters** ➔ **DNS blocklists** ➔ **Add blocklist**:

1. **AdGuard Base Filter** (Pre-installed) — Comprehensive general ad-blocking.
2. **OISD Blocklist (Big / Small)**:
   - URL: `https://big.oisd.nl` or `https://small.oisd.nl`
   - Zero false-positives, excellent for family environments.
3. **Steven Black Hosts**:
   - URL: `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`
   - Broad coverage of ads, telemetry, and adware.
4. **HaGeZi Multi PRO**:
   - URL: `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt`

---

## 🔀 Custom DNS Rewrites & Internal Domains

In **Filters** ➔ **DNS rewrites**, you can map friendly internal domain names:

| Domain Pattern | Target IP | Description |
| :--- | :--- | :--- |
| `router.lan` | `192.168.1.1` | Local Gateway |
| `nas.lan` | `192.168.1.100` | Local Storage |
| `*.internal.lan` | `<dev1-tailscale-ip>` | Dev1 Ingress |

---

## 💾 Backup & Data Protection

AdGuard Home configuration is stored in `/opt/homelab/data/adguard/conf/AdGuardHome.yaml`.

The automated backup script (`scripts/backup_homelab.sh`) archives:
- `conf/AdGuardHome.yaml` (filter lists, upstream DNS, rewrites, client settings)
- `work/data/` (query logs and statistics database)

---

## 🛠️ Troubleshooting & Operational Commands

| Task | Command |
| :--- | :--- |
| **Check Port 53 Binding** | `sudo ss -tulpn \| grep :53` |
| **Test DNS Resolution** | `dig @127.0.0.1 google.com` or `dig @<dev1-tailscale-ip> google.com` |
| **Test Ad-Blocking** | `dig @127.0.0.1 doubleclick.net` *(Should return `0.0.0.0`)* |
| **View Live Logs** | `docker logs -f adguardhome` |
| **Restart Container** | `cd /opt/homelab && docker compose restart adguardhome` |

---

## 🔗 Related Notes
- [[Service - Tailscale WireGuard Mesh|Tailscale WireGuard Mesh & MagicDNS]]
- [[Service - Caddy Reverse Proxy|Caddy Reverse Proxy Configuration]]
- [[Guide - Backup & Off-Site Sync|Homelab Backup & Snapshot Guide]]
