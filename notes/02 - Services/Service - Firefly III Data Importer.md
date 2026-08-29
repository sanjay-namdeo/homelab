---
title: "Service: Firefly III Data Importer (Bank Statement Importer)"
type: service
category: finance
host: dev2
status: active
tags:
  - homelab/service
  - category/finance
  - host/dev2
  - banking
  - import
aliases:
  - Firefly Importer
  - FIDI
  - Bank Importer
created: 2026-08-28
last_updated: 2026-08-29
url: "https://dev2.<tailnet>.ts.net:8443"
port: 8081
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Services MOC|📦 Services]] ➔ **Firefly III Data Importer**

# 📥 Service: Firefly III Data Importer (Automated Bank Importer)

**Firefly III Data Importer (FIDI)** is the official companion utility for Firefly III that converts and imports bank exports (CSV, CAMT.053, MT940, OFX, QIF, and Spectre API feeds) into transactions, creating accounts, tags, and categories automatically.

---

## 🏗️ Architecture & Deployment

- **Host Node:** `dev2`
- **Docker Image:** `fireflyiii/data-importer:latest`
- **Internal Port:** `127.0.0.1:8081`
- **Tailscale Ingress URL:** `https://dev2.<tailnet>.ts.net:8443` (via Tailscale Serve)
- **Import Staging Directory:** `/opt/homelab/data/dev2/firefly/import`
- **Docker Network:** Connected directly to `firefly_app` over internal bridge `firefly_net`.
- **Resource Constraints:** Max 256 MB RAM, 0.75 vCPU

```mermaid
graph LR
    User["👤 User (Web Browser)"] -->|HTTPS :8443| TS["⚡ Tailscale Serve (:8443)"]
    TS -->|HTTP :8080| FIDI["📥 Firefly Data Importer"]
    FIDI -->|REST API (OAuth Token)| FFA["💰 Firefly III Core (:8080)"]
```

---

## ⚙️ Configuration & Auto-Import Setup

### Connecting FIDI to Firefly Core
- **`FIREFLY_III_URL`**: `http://firefly_app:8080` (Internal Docker DNS)
- **`FIREFLY_III_ACCESS_TOKEN`**: OAuth Personal Access Token created in Firefly Core.
- **`IMPORT_DIR_ALLOWLIST`**: `/import`

---

## 🔗 Related Notes
- [[Service - Firefly III Core|Firefly III Core]]
- [[Disaster Recovery Runbook - dev2|Disaster Recovery Runbook: dev2]]
