---
title: "Service: Vaultwarden (Bitwarden Server)"
type: service
category: security
host: dev1
status: active
tags:
  - homelab/service
  - category/security
  - host/dev1
  - passwords
  - bitwarden
aliases:
  - Vaultwarden
  - Bitwarden Server
  - Password Manager
created: 2026-08-28
last_updated: 2026-08-29
url: "https://dev1.<tailnet>.ts.net"
port: 8080
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Services MOC|📦 Services]] ➔ **Vaultwarden**

# 🔑 Service: Vaultwarden (Bitwarden Server)

**Vaultwarden** is a lightweight, self-hosted implementation of the Bitwarden server API written in Rust. It is fully compatible with official Bitwarden apps, browser extensions, and CLI tools, while consuming only ~15–25 MB of idle RAM.

---

## 🏗️ Architecture & Deployment

- **Host Node:** `dev1`
- **Docker Image:** `vaultwarden/server:alpine`
- **Local Port:** `127.0.0.1:8080`
- **Ingress URL:** `https://dev1.<tailnet>.ts.net` (via Caddy on port 443)
- **Database Engine:** SQLite (with WAL mode enabled)
- **Storage Directory:** `/opt/homelab/data/vaultwarden`
- **Resource Constraints:** Max 128 MB RAM, 0.50 vCPU

```mermaid
graph LR
    Client["📱 Bitwarden App / Extension"] -->|Encrypted HTTPS| Caddy["⚡ Caddy Reverse Proxy (:443)"]
    Caddy -->|HTTP :8080| VW["🔑 Vaultwarden Server"]
    VW -->|ACID Transactions (WAL Mode)| SQLite[("🗄️ SQLite DB (/data/vaultwarden)")]
```

---

## ⚙️ Key Configuration & Security Flags

| Environment Variable | Recommended Value | Purpose |
| :--- | :--- | :--- |
| `SIGNUPS_ALLOWED` | `false` (after initial admin creation) | Prevents unauthorized registrations |
| `INVITATIONS_ALLOWED` | `false` | Disables non-admin invitations |
| `WEBSOCKET_ENABLED` | `true` | Enables instant sync push to clients |
| `DOMAIN` | `https://dev1.<tailnet>.ts.net` | Enforces HTTPS origin matching |
| `EXTENDED_LOGGING` | `true` | Detailed audit trail |

> [!IMPORTANT]
> Modern browsers enforce the **WebCrypto API standard**, requiring HTTPS to encrypt and decrypt password vaults. Vaultwarden will not operate over unencrypted HTTP.

---

## 📱 Connecting Bitwarden Clients

1. Download the official **Bitwarden** desktop app, browser extension, or mobile app.
2. On the login screen, click the **Settings (⚙️ gear icon)**.
3. Under **Server URL**, enter:
   `https://dev1.<tailnet>.ts.net`
4. Save and log in with your master credentials.

---

## 💾 Backup & Disaster Recovery

- **Live Snapshot Method:** Atomic non-blocking snapshot using Python's `sqlite3.backup()` API.
- **Runbook:** [[Disaster Recovery Runbook - dev1|dev1 Disaster Recovery Runbook]]
- **Restoration Command:**
  ```bash
  sudo bash /opt/homelab/scripts/restore_homelab.sh --host dev1 --latest
  ```

---

## 🔗 Related Notes
- [[Ingress & Caddy Reverse Proxy|Caddy Reverse Proxy Guide]]
- [[Guide - Backup & Off-Site Sync (Cloudflare R2)|Backup & Sync Guide]]
- [[Disaster Recovery Runbook - dev1|Disaster Recovery Runbook: dev1]]
