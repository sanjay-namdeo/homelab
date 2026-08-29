---
title: "Disaster Recovery Runbook - {{host}} ({{role}})"
type: runbook
category: dr
host: {{host}}
status: active
tags:
  - homelab/runbook
  - category/dr
  - host/{{host}}
aliases:
  - DR Runbook {{host}}
created: {{date}}
last_updated: {{date}}
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Disaster Recovery MOC|🚑 Disaster Recovery]] ➔ **DR Runbook: {{host}}**

# 🚑 Disaster Recovery Runbook — Host: `{{host}}`
**Target Host:** `{{host}}`  
**Target RTO:** < 5 Minutes  
**Target RPO:** < 24 Hours

---

## 📋 Emergency Quick Action Summary

```bash
sudo bash /opt/homelab/scripts/restore_homelab.sh --latest
```

---

## 🏛️ Architecture & Data Mapping (`{{host}}`)

| Component | Host Data Path | Description | Permissions |
| :--- | :--- | :--- | :--- |
| **Secrets** | `/opt/homelab/hosts/{{host}}/.env` | Secret environment file | `0600` (root:root) |

---

## 🚨 Disaster Recovery Scenarios & Procedures

### Scenario A: Accidental Deletion / Corruption
1. Run restoration: `sudo bash /opt/homelab/scripts/restore_homelab.sh --latest`

---

## ✅ Post-Restoration Verification Checklist

- [ ] Containers running (`docker ps`).
- [ ] Endpoints reachable.
- [ ] Healthcheck passed (`sudo bash /opt/homelab/scripts/healthcheck.sh {{host}}`).

---

## 🔗 Related Notes
- [[00 - Disaster Recovery MOC|Disaster Recovery MOC]]
- [[Guide - Backup & Off-Site Sync (Cloudflare R2)|Backup Guide]]
