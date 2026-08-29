---
title: "Disaster Recovery & Backups Map of Content"
type: moc
category: dr
host: multi-host
status: active
tags:
  - homelab
  - homelab/moc
  - dr
  - backup
  - disaster-recovery
aliases:
  - Disaster Recovery MOC
  - Backup & DR Hub
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ **Disaster Recovery & Backups**

# 🚑 Disaster Recovery & Backups Map of Content

This section contains our comprehensive **3-2-1 backup strategy**, point-in-time snapshot specifications, bare-metal restoration workflows, dedicated host recovery runbooks, and live testing protocols.

---

## 🎯 Target Recovery Objectives

- **Recovery Time Objective (RTO):** < 5 minutes (from snapshot archive to fully operational service stack).
- **Recovery Point Objective (RPO):** < 24 hours (nightly automated snapshots).

---

## 📑 Section Documents

- [[Guide - Backup & Off-Site Sync (Cloudflare R2)|Backup & Off-Site Sync Guide]]
  *3-2-1 backup architecture, non-blocking online snapshots (SQLite & MariaDB), 14-day retention, and AES-256 encrypted Cloudflare R2 sync.*
- [[Guide - Disaster Recovery & Bare-Metal Restore|Disaster Recovery & Bare-Metal Restore Guide]]
  *End-to-end recovery workflows, 1-command snapshot restoration, bare-metal server rebuilding, and single-service recovery.*
- [[Disaster Recovery Runbook - dev1|Disaster Recovery Runbook: dev1]]
  *Step-by-step restoration runbook for Vaultwarden, AdGuard Home, Uptime Kuma, and Caddy Reverse Proxy.*
- [[Disaster Recovery Runbook - dev2|Disaster Recovery Runbook: dev2]]
  *Step-by-step restoration runbook for Firefly III, MariaDB, Obsidian WebDAV, Flatnotes, and Beszel Hub.*
- [[Disaster Recovery Verification & Live Testing|Disaster Recovery Verification & Live Testing Protocol]]
  *Validation methodology, live disaster drill protocol, test verification tokens, and audit checklists.*

---

## ⚡ 1-Command Automated Recovery

```bash
# Complete point-in-time recovery using latest local backup:
sudo bash /opt/homelab/scripts/restore_homelab.sh --latest

# Fetch off-site cloud backup and restore:
sudo rclone copy r2-crypt:homelab/backups/ /opt/homelab/data/backups/ --config /opt/homelab/data/rclone/rclone.conf
sudo bash /opt/homelab/scripts/restore_homelab.sh --latest
```

---

## 🔗 Related Sections
- [[00 - Architecture MOC|📐 01 - Architecture & Infrastructure]]
- [[00 - Services MOC|📦 02 - Core Services]]
- [[00 - Operations MOC|🛠️ 03 - Operations & Guides]]
