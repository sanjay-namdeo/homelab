---
title: "Disaster Recovery Runbook - dev1 (Identity, DNS & Edge Services)"
type: runbook
category: dr
host: dev1
status: active
tags:
  - homelab/runbook
  - category/dr
  - host/dev1
  - vaultwarden
  - adguard
  - uptime-kuma
  - caddy
aliases:
  - DR Runbook dev1
  - dev1 Recovery Runbook
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Disaster Recovery MOC|🚑 Disaster Recovery]] ➔ **DR Runbook: dev1**

# 🚑 Disaster Recovery Runbook — Host: `dev1`
**Target Host:** `dev1` (`<dev1-tailscale-ip>` / `dev1.<tailnet>.ts.net`)  
**Services:** Vaultwarden (Passwords), AdGuard Home (DNS Sinkhole), Uptime Kuma (Monitors), Caddy Reverse Proxy, Beszel Agent.  
**Target RTO (Recovery Time Objective):** < 5 Minutes  
**Target RPO (Recovery Point Objective):** < 24 Hours (Nightly automated snapshots)

---

## 📋 Emergency Quick Action Summary

```bash
# ==============================================================================
# ⚡ 1-COMMAND RECOVERY (LOCAL SNAPSHOT)
# ==============================================================================
sudo bash /opt/homelab/scripts/restore_homelab.sh --latest

# ==============================================================================
# ☁️ 1-COMMAND RECOVERY (CLOUDFLARE R2 CLOUD BACKUP)
# ==============================================================================
rclone copy r2-crypt:homelab/backups/ /opt/homelab/data/backups/ --config /opt/homelab/data/rclone/rclone.conf
sudo bash /opt/homelab/scripts/restore_homelab.sh --latest
```

---

## 🏛️ Architecture & Data Mapping (`dev1`)

| Component | Host Data Path | Description | Permissions |
| :--- | :--- | :--- | :--- |
| **Secrets & Env** | `/opt/homelab/hosts/dev1/.env` | Vaultwarden secrets, domain configuration | `0600` (root:root) |
| **Compose Definition**| `/opt/homelab/hosts/dev1/docker-compose.yml` | Container definitions, resource caps, network | `0644` (root:root) |
| **Vaultwarden DB** | `/opt/homelab/data/vaultwarden/db.sqlite3` | SQLite password vault with WAL journal | `0700` (root:root) |
| **Vaultwarden Keys**| `/opt/homelab/data/vaultwarden/rsa_key.pem`| RSA private key for JWT signing | `0600` (root:root) |
| **AdGuard Home Config**| `/opt/homelab/data/adguard/conf/` | YAML configuration and custom rules | `0755` (root:root) |
| **Uptime Kuma DB** | `/opt/homelab/data/uptime-kuma/kuma.db` | SQLite monitor definitions and history | `0755` (`ubuntu:ubuntu`) |
| **Caddy TLS & Proxy**| `/opt/homelab/Caddyfile` | Ingress rules & Tailscale socket binding | `0644` (root:root) |
| **Local Backups** | `/opt/homelab/data/backups/` | Timestamped, permission-locked archives | `0700` (root:root) |

---

## 🚨 Disaster Recovery Scenarios & Procedures

### Scenario A: Accidental File / Database Corruption (Server Online)
1. **Identify the latest valid backup:**
   ```bash
   ls -la /opt/homelab/data/backups/homelab_backup_dev1_*.tar.gz
   ```
2. **Execute non-destructive restore:**
   ```bash
   sudo bash /opt/homelab/scripts/restore_homelab.sh --latest
   ```
3. **Verify running containers and endpoints:**
   ```bash
   docker ps
   sudo bash /opt/homelab/scripts/healthcheck.sh dev1
   ```

### Scenario B: Complete Hardware / Bare-Metal Failure (New VM)
1. **Provision Fresh Ubuntu 24.04 VM** and configure Tailscale:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up --ssh --accept-dns=true
   ```
2. **Install Docker Engine**:
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker ubuntu
   ```
3. **Clone Homelab Repository**:
   ```bash
   git clone git@github.com:sanjay-namdeo/homelab.git /opt/homelab
   cd /opt/homelab
   ```
4. **Pull Offsite Backup from Cloudflare R2**:
   ```bash
   mkdir -p /opt/homelab/data/rclone /opt/homelab/data/backups
   # Restore rclone.conf
   rclone copy r2-crypt:homelab/backups/ /opt/homelab/data/backups/ --config /opt/homelab/data/rclone/rclone.conf
   ```
5. **Run Restore Script**:
   ```bash
   sudo bash /opt/homelab/scripts/restore_homelab.sh --latest
   ```

---

## ✅ Post-Restoration Verification Checklist

- [ ] `docker ps` shows `vaultwarden`, `adguardhome`, `caddy`, `uptime-kuma`, `beszel_agent` running.
- [ ] Vaultwarden login test: `https://dev1.<tailnet>.ts.net` (WebCrypto HTTPS working).
- [ ] AdGuard Home DNS test: `dig @<dev1-tailscale-ip> google.com +short` returns valid IP.
- [ ] AdGuard Web UI: `https://dev1.<tailnet>.ts.net:8081` accessible without SSL warning.
- [ ] Uptime Kuma: `https://dev1.<tailnet>.ts.net:3001` shows all green monitors.
- [ ] Health diagnostic run completes with zero failures: `sudo bash /opt/homelab/scripts/healthcheck.sh dev1`.

---

## 🔗 Related Notes
- [[Disaster Recovery Runbook - dev2|dev2 Disaster Recovery Runbook]]
- [[Guide - Backup & Off-Site Sync (Cloudflare R2)|Backup & Sync Guide]]
- [[Guide - Disaster Recovery & Bare-Metal Restore|Disaster Recovery Overview]]
- [[Disaster Recovery Verification & Live Testing|Live Testing Protocol]]
