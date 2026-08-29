---
title: "Disaster Recovery Runbook - dev2 (Finance & Monitoring)"
type: runbook
category: dr
host: dev2
status: active
tags:
  - homelab/runbook
  - category/dr
  - host/dev2
  - firefly
  - mariadb
  - obsidian
  - beszel
aliases:
  - DR Runbook dev2
  - dev2 Recovery Runbook
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Disaster Recovery MOC|🚑 Disaster Recovery]] ➔ **DR Runbook: dev2**

# 🚑 Disaster Recovery Runbook — Host: `dev2`
**Target Host:** `dev2` (`<dev2-tailscale-ip>` / `dev2.<tailnet>.ts.net`)  
**Services:** Firefly III Core, Firefly Data Importer, MariaDB 11.4 LTS, Obsidian WebDAV Sync, Flatnotes Web Editor, Beszel Hub, Beszel Agent.  
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

## 🏛️ Architecture & Data Mapping (`dev2`)

| Component | Host Data Path | Description | Permissions |
| :--- | :--- | :--- | :--- |
| **Secrets & Env** | `/opt/homelab/hosts/dev2/.env` | Database passwords, `APP_KEY`, WebDAV & Flatnotes credentials | `0600` (root:root) |
| **Compose Definition**| `/opt/homelab/hosts/dev2/docker-compose.yml` | Container definitions, resource caps, network bridge | `0644` (root:root) |
| **MariaDB Storage** | `/opt/homelab/data/dev2/firefly/db/` | MariaDB relational database engine storage (`firefly` DB) | `0755` (`999:999`) |
| **Firefly Uploads** | `/opt/homelab/data/dev2/firefly/upload/` | Invoices, receipts, and user attachments | `0775` (`www-data:www-data`) |
| **Firefly Imports** | `/opt/homelab/data/dev2/firefly/import/` | Bank statement auto-import staging directory | `0775` (`ubuntu:ubuntu`) |
| **Obsidian Vault** | `/opt/homelab/data/dev2/obsidian/vault/` | Markdown knowledge base notes and attachments | `0775` (`82:82`) |
| **Flatnotes Index** | `/opt/homelab/data/dev2/obsidian/flatnotes_data/`| Flatnotes search metadata and user preferences | `0775` (`82:82`) |
| **Beszel Hub Metrics**| `/opt/homelab/data/dev2/beszel/data/` | Historical SQLite metrics database (`data.db`) & SSH keys | `0755` (`ubuntu:ubuntu` / root) |
| **Local Backups** | `/opt/homelab/data/backups/` | Timestamped, permission-locked archives | `0700` (root:root) |

---

## 🚨 Disaster Recovery Scenarios & Procedures

### Scenario A: MariaDB Corruption / Accidental Deletion
1. **Locate latest backup archive:**
   ```bash
   ls -lt /opt/homelab/data/backups/homelab_backup_dev2_*.tar.gz | head -n 1
   ```
2. **Run Restore Script:**
   ```bash
   sudo bash /opt/homelab/scripts/restore_homelab.sh --latest
   ```
3. **Verify MariaDB database health:**
   ```bash
   docker exec firefly_db mariadb-admin ping -u firefly -p"$(grep '^DB_PASSWORD=' /opt/homelab/hosts/dev2/.env | cut -d= -f2-)"
   ```

### Scenario B: Bare-Metal Server Rebuild (Complete Loss of dev2)
1. **Provision Fresh Ubuntu 24.04 VM** and join Tailscale:
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
   # (Copy rclone.conf)
   rclone copy r2-crypt:homelab/backups/ /opt/homelab/data/backups/ --config /opt/homelab/data/rclone/rclone.conf
   ```
5. **Run Automated Restore**:
   ```bash
   sudo bash /opt/homelab/scripts/restore_homelab.sh --latest
   ```
6. **Re-enable Tailscale Serve HTTPS Ingress**:
   ```bash
   sudo tailscale serve --bg --https=443 http://127.0.0.1:8080
   sudo tailscale serve --bg --https=8443 http://127.0.0.1:8081
   sudo tailscale serve --bg --https=8082 http://127.0.0.1:8082
   sudo tailscale serve --bg --https=8083 http://127.0.0.1:8083
   sudo tailscale serve --bg --https=8090 http://127.0.0.1:8090
   ```

---

## ✅ Post-Restoration Verification Checklist

- [ ] All 7 containers active (`firefly_app`, `firefly_db`, `firefly_importer`, `obsidian_webdav`, `obsidian_web`, `beszel`, `beszel_agent`).
- [ ] Firefly III login & dashboard loading: `https://dev2.<tailnet>.ts.net`.
- [ ] Obsidian WebDAV authentication & sync test: `https://dev2.<tailnet>.ts.net:8082/data/`.
- [ ] Flatnotes web note search & save: `https://dev2.<tailnet>.ts.net:8083`.
- [ ] Beszel Hub telemetry charts live: `https://dev2.<tailnet>.ts.net:8090`.
- [ ] Healthcheck tool passes with all green checks: `sudo bash /opt/homelab/scripts/healthcheck.sh dev2`.

---

## 🔗 Related Notes
- [[Disaster Recovery Runbook - dev1|dev1 Disaster Recovery Runbook]]
- [[Guide - Backup & Off-Site Sync (Cloudflare R2)|Backup & Sync Guide]]
- [[Guide - Disaster Recovery & Bare-Metal Restore|Disaster Recovery Overview]]
- [[Disaster Recovery Verification & Live Testing|Live Testing Protocol]]
