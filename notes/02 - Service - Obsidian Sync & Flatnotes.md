---
title: "Service: Obsidian Tri-Platform Sync & Flatnotes"
type: service
category: knowledge
host: dev2
status: active
tags:
  - homelab/service
  - category/knowledge
  - host/dev2
  - obsidian
  - flatnotes
  - webdav
aliases:
  - Obsidian Sync
  - Flatnotes Web Wiki
  - Knowledge Base Service
created: 2026-08-28
last_updated: 2026-08-29
url: "https://dev2.<tailnet>.ts.net:8083"
port: 8083
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Services MOC|📦 Services]] ➔ **Obsidian Sync & Flatnotes**

# 📝 Service: Obsidian Tri-Platform Sync & Flatnotes

This service stack provides a private, self-hosted note-taking infrastructure that connects official **Obsidian Desktop and Mobile apps** via WebDAV while simultaneously offering **Flatnotes** as a lightweight browser-based markdown editor.

---

## 🏗️ Architecture & Deployment

- **Host Node:** `dev2`
- **WebDAV Backend Image:** `bytemark/webdav:latest` (Port `127.0.0.1:8082`)
- **Flatnotes Web Editor Image:** `dullage/flatnotes:latest` (Port `127.0.0.1:8083`)
- **Tailscale Endpoints:**
  - WebDAV Sync: `https://dev2.<tailnet>.ts.net:8082/data/`
  - Flatnotes Web UI: `https://dev2.<tailnet>.ts.net:8083`
- **Shared Vault Storage:** `/opt/homelab/data/dev2/obsidian/vault` (Shared storage between WebDAV and Flatnotes)
- **Flatnotes Search Index:** `/opt/homelab/data/dev2/obsidian/flatnotes_data`
- **Permissions:** UID/GID `82:82` (`www-data`)
- **Resource Limits:** WebDAV Max 64 MB RAM (~5MB idle), Flatnotes Max 128 MB RAM (~50MB idle)

```mermaid
graph TD
    subgraph ClientDevices ["📱 Client Devices"]
        ObsidianPC["💻 Obsidian Desktop (Windows / Mac / Linux)"]
        ObsidianMobile["📱 Obsidian Mobile (iOS / Android)"]
        WebBrowser["🌐 Web Browser (Any Device)"]
    end

    subgraph dev2 ["🖥️ dev2 Infrastructure"]
        TS_Serve["⚡ Tailscale Serve TLS Engine"]
        WebDAV["📁 Obsidian WebDAV Backend (:8082)"]
        Flatnotes["📝 Flatnotes Web Editor (:8083)"]
        VaultDir[("🗄️ Shared Vault Storage\n/opt/homelab/data/dev2/obsidian/vault")]
    end

    ObsidianPC <-->|Remotely Save WebDAV HTTPS (:8082)| TS_Serve
    ObsidianMobile <-->|Remotely Save WebDAV HTTPS (:8082)| TS_Serve
    WebBrowser <-->|Web UI HTTPS (:8083)| TS_Serve

    TS_Serve --> WebDAV
    TS_Serve --> Flatnotes

    WebDAV <--> VaultDir
    Flatnotes <--> VaultDir
```

---

## 📱 Client Setup & Documentation Sync

- **Obsidian Multi-Device Setup:** [[Guide - Obsidian Multi-Device Setup & Remotely Save|Complete Obsidian Client & Remotely Save Guide]]
- **Synchronizing Git Notes to Vault:**
  ```bash
  sudo bash /opt/homelab/scripts/sync_notes_to_vault.sh
  ```

---

## 💾 Backup & Data Protection

- The entire Markdown vault directory `/opt/homelab/data/dev2/obsidian/vault` and Flatnotes metadata `/opt/homelab/data/dev2/obsidian/flatnotes_data` are archived daily via `scripts/backup_homelab.sh --host dev2`.

---

## 🔗 Related Notes
- [[Guide - Obsidian Multi-Device Setup & Remotely Save|Obsidian Client Setup Guide]]
- [[Disaster Recovery Runbook - dev2|dev2 Disaster Recovery Runbook]]
- [[Guide - Backup & Off-Site Sync (Cloudflare R2)|Backup Guide]]
