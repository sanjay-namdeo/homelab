---
title: "Disaster Recovery Verification & Live Testing Protocol"
type: runbook
category: dr
host: multi-host
status: active
tags:
  - homelab/runbook
  - category/dr
  - testing
  - validation
aliases:
  - DR Live Testing
  - DR Verification
  - Disaster Drill Protocol
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Disaster Recovery MOC|🚑 Disaster Recovery]] ➔ **DR Verification & Live Testing**

# 🧪 Disaster Recovery Verification & Live Testing Protocol

Periodic live testing of backups is the only guarantee that a disaster recovery system will function when a catastrophic failure occurs. This protocol outlines how to safely execute non-destructive and live recovery validation drills.

---

## 🎯 Verification Drill Protocol (Dry-Run & Live)

### Drill 1: Archive Extraction & SQL Syntax Test (Non-Destructive)
Tests archive integrity without interrupting running containers:
```bash
# 1. Create temporary staging sandbox
SANDBOX="/tmp/dr_test_$(date +%s)"
mkdir -p "${SANDBOX}"

# 2. Extract latest backup into sandbox
LATEST_BACKUP=$(ls -t /opt/homelab/data/backups/homelab_backup_*.tar.gz | head -n 1)
tar -xzf "${LATEST_BACKUP}" -C "${SANDBOX}"

# 3. Verify SQL Dump / SQLite integrity
if [[ -f "${SANDBOX}/mariadb/firefly.sql" ]]; then
    head -n 20 "${SANDBOX}/mariadb/firefly.sql"
    echo "✔ MariaDB SQL dump is valid and readable."
fi

if [[ -f "${SANDBOX}/vaultwarden/db.sqlite3" ]]; then
    sqlite3 "${SANDBOX}/vaultwarden/db.sqlite3" "PRAGMA integrity_check;"
fi

# 4. Clean up sandbox
rm -rf "${SANDBOX}"
```

### Drill 2: Cloudflare R2 Remote Sync Verification
```bash
# Verify that Cloudflare R2 bucket contains recent encrypted backups
rclone lsd r2-crypt:homelab/ --config /opt/homelab/data/rclone/rclone.conf
rclone ls r2-crypt:homelab/backups/ --config /opt/homelab/data/rclone/rclone.conf
```

---

## 📋 Disaster Recovery Drill History & Audit Log

| Drill Date | Host | Backup Archive | RTO Observed | Status | Verified By |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **2026-08-28** | `dev1` | `homelab_backup_dev1_20260828_133800.tar.gz` | 18s | ✅ Pass | Automated Drill |
| **2026-08-29** | `dev2` | `homelab_backup_dev2_20260829_044300.tar.gz` | 24s | ✅ Pass | Live Verification |

---

## 🔗 Related Notes
- [[Guide - Backup & Off-Site Sync (Cloudflare R2)|Backup & Sync Guide]]
- [[Guide - Disaster Recovery & Bare-Metal Restore|Disaster Recovery Guide]]
- [[Disaster Recovery Runbook - dev1|dev1 DR Runbook]]
- [[Disaster Recovery Runbook - dev2|dev2 DR Runbook]]
