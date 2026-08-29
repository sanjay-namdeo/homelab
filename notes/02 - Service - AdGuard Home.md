---
title: "Service: AdGuard Home (Network DNS Sinkhole)"
type: service
category: networking
host: dev1
status: active
tags:
  - homelab/service
  - category/networking
  - category/security
  - host/dev1
  - dns
  - adblocking
aliases:
  - AdGuard Home
  - AdGuard DNS
  - DNS Sinkhole
created: 2026-08-28
last_updated: 2026-08-29
url: "https://dev1.<tailnet>.ts.net:8081"
port: 8081
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Services MOC|📦 Services]] ➔ **AdGuard Home**

# 🛡️ Service: AdGuard Home (Network-Wide DNS & Ad-Blocking)

**AdGuard Home** acts as a network-wide DNS sinkhole, filtering out advertisements, trackers, phishing, and malware domains across all devices on the Tailscale mesh before connections are established.

---

## 🏗️ Architecture & Deployment

- **Host Node:** `dev1`
- **Docker Image:** `adguard/adguardhome:latest`
- **Web UI Port:** `127.0.0.1:8081` (Proxied via Caddy to `https://dev1.<tailnet>.ts.net:8081`)
- **DNS Server Port:** Port `53` (TCP/UDP) bound to Tailscale IP (`<dev1-tailscale-ip>:53`) and loopback
- **Data & Configuration:** `/opt/homelab/data/adguard/conf` and `/opt/homelab/data/adguard/work`
- **Resource Constraints:** Max 128 MB RAM, 0.50 vCPU

```mermaid
graph TD
    Client["📱 Tailscale Mesh Clients (Laptops / Phones)"] -->|Encrypted DNS Queries (Port 53)| AG["🛡️ AdGuard Home DNS Resolver (<dev1-tailscale-ip>)"]
    AG -->|Check Blocklists & Rules| Filter{"Is Domain Blocked?"}
    Filter -->|Yes (Ad / Tracker)| Sinkhole["🚫 Return 0.0.0.0 (Sinkhole)"]
    Filter -->|No (Legitimate)| Upstream["🔒 Encrypted Upstream DNS (DoH/DoT)\nCloudflare / Quad9"]
    Upstream --> CleanIP["✅ Return Valid IP Address"]
```

---

## 🌐 Upstream DNS & Blocklist Configuration

### Recommended Upstream DNS Providers (DoH / DoT)
```text
https://dns.cloudflare.com/dns-query
tls://dns.quad9.net
https://dns.google/dns-query
```

### Tailscale MagicDNS Integration
To route all device traffic through AdGuard Home:
1. Open the [Tailscale Admin Console → DNS](https://login.tailscale.com/admin/dns).
2. Under **Nameservers**, add Custom Nameserver: `<dev1-tailscale-ip>` (the Tailscale IP of `dev1`).
3. Enable **Override local DNS**.

---

## 💾 Backup & Maintenance

- Configuration is saved in `/opt/homelab/data/adguard/conf/AdGuardHome.yaml`.
- Backed up daily via `scripts/backup_homelab.sh --host dev1`.

---

## 🔗 Related Notes
- [[Ingress & Caddy Reverse Proxy|Caddy Reverse Proxy]]
- [[Network & Tailscale WireGuard Mesh|Tailscale Mesh Networking]]
- [[Disaster Recovery Runbook - dev1|Disaster Recovery Runbook: dev1]]
