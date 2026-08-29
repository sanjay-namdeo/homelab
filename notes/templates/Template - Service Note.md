---
title: "Service: {{title}}"
type: service
category: {{category}} # security | networking | finance | monitoring | knowledge
host: {{host}} # dev1 | dev2
status: active # active | testing | maintenance
tags:
  - homelab/service
  - category/{{category}}
  - host/{{host}}
aliases:
  - {{alias_1}}
  - {{alias_2}}
created: {{date}}
last_updated: {{date}}
url: "https://{{host}}.<tailnet>.ts.net:{{port}}"
port: {{port}}
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Services MOC|📦 Services]] ➔ **{{title}}**

# 📦 Service: {{title}}

**{{title}}** is a self-hosted service providing {{brief_description}}.

---

## 🏗️ Architecture & Deployment

- **Host Node:** `{{host}}`
- **Docker Image:** `{{image_name}}`
- **Internal Port:** `127.0.0.1:{{port}}`
- **Ingress Access:** `https://{{host}}.<tailnet>.ts.net:{{port}}`
- **Data Storage:** `/opt/homelab/data/{{service_name}}`
- **Resource Constraints:** Max {{memory_limit}} RAM, {{cpu_limit}} vCPU

```mermaid
graph LR
    Client["📱 Tailscale Client"] -->|HTTPS| Proxy["⚡ Reverse Proxy"]
    Proxy -->|HTTP :{{port}}| App["📦 {{title}}"]
```

---

## ⚙️ Key Configuration & Environment Variables

| Variable | Recommended Value | Purpose |
| :--- | :--- | :--- |
| `ENV_VAR_1` | `value` | Description |

---

## 💾 Backup & Data Protection

- Data directory `/opt/homelab/data/{{service_name}}` is archived daily by `scripts/backup_homelab.sh --host {{host}}`.

---

## 🔗 Related Notes
- [[00 - Services MOC|Services Directory]]
- [[Guide - Backup & Off-Site Sync (Cloudflare R2)|Backup & Sync Guide]]
