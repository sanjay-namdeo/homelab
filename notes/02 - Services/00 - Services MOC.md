---
title: "Services Map of Content"
type: moc
category: services
host: multi-host
status: active
tags:
  - homelab
  - homelab/moc
  - services
aliases:
  - Services MOC
  - Service Directory
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ **Core Services**

# 📦 Core Services Directory

This Map of Content catalogues all active self-hosted services running in the homelab across `dev1` and `dev2`.

---

## 📋 Comprehensive Service Directory

| Service | Host | Port | Ingress | Category | Access URL | Documentation |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Vaultwarden** | `dev1` | `:8080` | Caddy (`:443`) | Security | `https://dev1.<tailnet>.ts.net` | [[Service - Vaultwarden\|Vaultwarden Note]] |
| **AdGuard Home** | `dev1` | `:8081` | Caddy (`:8081`) | DNS / Security | `https://dev1.<tailnet>.ts.net:8081` | [[Service - AdGuard Home\|AdGuard Home Note]] |
| **AdGuard DNS** | `dev1` | `:53` | Tailscale IP | DNS Sinkhole | `<dev1-tailscale-ip>:53` | [[Service - AdGuard Home\|AdGuard DNS Note]] |
| **Uptime Kuma** | `dev1` | `:3001` | Caddy (`:3001`) | Monitoring | `https://dev1.<tailnet>.ts.net:3001` | [[Service - Uptime Kuma\|Uptime Kuma Note]] |
| **Beszel Agent** | `dev1` | `:45876`| Host Port | Telemetry | `dev1.<tailnet>.ts.net:45876` | [[Service - Beszel Server Monitoring\|Beszel Note]] |
| **Firefly III Core** | `dev2` | `:8080` | Tailscale Serve | Finance | `https://dev2.<tailnet>.ts.net` | [[Service - Firefly III Core\|Firefly III Note]] |
| **Firefly Importer** | `dev2` | `:8081` | Tailscale Serve | Finance | `https://dev2.<tailnet>.ts.net:8443` | [[Service - Firefly III Data Importer\|Firefly Importer Note]] |
| **Obsidian WebDAV** | `dev2` | `:8082` | Tailscale Serve | Knowledge | `https://dev2.<tailnet>.ts.net:8082/data/` | [[Service - Obsidian Sync & Flatnotes\|Obsidian Note]] |
| **Flatnotes Web** | `dev2` | `:8083` | Tailscale Serve | Knowledge | `https://dev2.<tailnet>.ts.net:8083` | [[Service - Obsidian Sync & Flatnotes\|Flatnotes Note]] |
| **Beszel Hub** | `dev2` | `:8090` | Tailscale Serve | Telemetry Hub | `https://dev2.<tailnet>.ts.net:8090` | [[Service - Beszel Server Monitoring\|Beszel Hub Note]] |
| **Beszel Agent** | `dev2` | Socket | Unix Socket | Telemetry Node| `/beszel_socket/beszel.sock` | [[Service - Beszel Server Monitoring\|Beszel Agent Note]] |

---

## 🏷️ Services by Category

### 🔐 Security & Identity
- [[Service - Vaultwarden|Vaultwarden Password Manager]]
- [[Service - AdGuard Home|AdGuard Home DNS Filter]]

### 💰 Personal Finance
- [[Service - Firefly III Core|Firefly III Accounting Engine]]
- [[Service - Firefly III Data Importer|Firefly III Statement Importer]]

### 📝 Knowledge Base & Notes
- [[Service - Obsidian Sync & Flatnotes|Obsidian WebDAV & Flatnotes Web Editor]]

### 📊 Monitoring & Observability
- [[Service - Uptime Kuma|Uptime Kuma Uptime & SSL Monitor]]
- [[Service - Beszel Server Monitoring|Beszel Server Telemetry Hub & Agents]]

---

## 🔗 Related Sections
- [[00 - Architecture MOC|📐 01 - Architecture & Infrastructure]]
- [[00 - Operations MOC|🛠️ 03 - Operations & Guides]]
- [[00 - Disaster Recovery MOC|🚑 04 - Disaster Recovery & Backups]]
