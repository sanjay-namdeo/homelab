# Personal Cloud & Multi-Host Homelab

A lightweight, production-grade, and self-hosted **Homelab Infrastructure** organized as a multi-host monorepo for resource-efficient servers (e.g., 1 GB RAM cloud VMs, Raspberry Pis, or home servers).

---

## 🏛️ Multi-Host Architecture Overview

```mermaid
graph TD
    Client["📱 Tailscale Devices (Laptop / Phone / Tablet)"]

    subgraph TailscaleMesh ["🔐 Encrypted Tailscale WireGuard Mesh (*.ts.net)"]
        TS1["dev1 (<dev1-tailscale-ip>)"]
        TS2["dev2 (<dev2-tailscale-ip>)"]
    end

    subgraph HostDev1 ["🖥️ Host: dev1 (Core Infrastructure)"]
        Caddy["⚡ Caddy Reverse Proxy (TLS :443, :8081, :3001)"]
        VW["🔑 Vaultwarden (:8080)"]
        AG["🛡️ AdGuard Home (:53 DNS, :8081 Web)"]
        UK["📊 Uptime Kuma (:3001 Web)"]
    end

    subgraph HostDev2 ["🖥️ Host: dev2 (Finance, Knowledge Hub & Monitoring)"]
        TS_Serve["⚡ Tailscale Serve (:443, :8443, :8082, :8083, :8090 TLS)"]
        FF["💰 Firefly III Core (:8080)"]
        FDI["📥 Data Importer (:8081)"]
        ObsDAV["📁 Obsidian WebDAV Sync (:8082)"]
        ObsWeb["📝 Obsidian Flatnotes Web (:8083)"]
        Beszel["📊 Beszel Hub & Agent (:8090)"]
        DB[("🗄️ MariaDB Database")]
    end

    Client -->|HTTPS / DNS| TS1
    TS1 --> Caddy
    Caddy -->|HTTPS :443| VW
    Caddy -->|HTTPS :8081| AG
    Caddy -->|HTTPS :3001| UK
    TS1 -.->|DNS Port 53| AG

    Client -->|HTTPS :443 / :8443 / :8082 / :8083 / :8090| TS2
    TS2 --> TS_Serve
    TS_Serve -->|:443| FF
    TS_Serve -->|:8443| FDI
    TS_Serve -->|:8082| ObsDAV
    TS_Serve -->|:8083| ObsWeb
    TS_Serve -->|:8090| Beszel
    FF --> DB
    FDI --> FF
```

---

## 🔒 Zero Domain & Free SSL Model

Modern browsers enforce the **WebCrypto API standard**, requiring HTTPS to encrypt and decrypt password vaults. 

This repository leverages **Tailscale MagicDNS** and **Tailscale TLS** to eliminate the need for:
- ❌ Purchasing a custom domain
- ❌ Managing public DNS records
- ❌ Manually provisioning SSL certificates
- ❌ Opening firewall ports 80/443 to the public internet

Tailscale provisions free, trusted **Let's Encrypt SSL certificates** automatically for your machine's `*.ts.net` address across all hosted services (Vaultwarden, AdGuard Home, Uptime Kuma on dev1; Firefly III on dev2).

---

## 📁 Repository Structure (Directory-per-Host)

```text
homelab/
├── hosts/
│   ├── dev1/                      # Host dev1: Core Privacy & Cloud Stack
│   │   ├── docker-compose.yml     # Vaultwarden, AdGuard Home, Uptime Kuma, Caddy
│   │   ├── Caddyfile              # Tailscale TLS reverse proxy configuration
│   │   ├── .env.example
│   │   └── README.md
│   │
│   └── dev2/                      # Host dev2: Personal Finance Stack
│       ├── docker-compose.yml     # Firefly III, Data Importer & MariaDB (tuned for 1GB RAM)
│       ├── .env.example
│       └── README.md
│
├── notes/                         # Obsidian & Flatnotes Knowledge Base Vault
│   ├── 00 - Homelab Hub.md        # Master Map of Content & Live Dashboard
│   ├── 01 - Architecture & Infrastructure/ # Architecture, Topology, Tailscale & Security
│   ├── 02 - Services/             # Individual Service Notes (Vaultwarden, Firefly, etc.)
│   ├── 03 - Operations & Guides/  # SOPs, Alerting & Multi-Device Setup
│   ├── 04 - Disaster Recovery & Backups/ # Backup Strategy & Host Runbooks
│   ├── templates/                 # Reusable Obsidian Note Templates
│   └── .obsidian/                 # Obsidian Vault App & Plugin Configuration
│
├── scripts/                       # Shared operational automation
│   ├── deploy_stack.sh           # Automated deployment with host auto-detection
│   ├── backup_homelab.sh         # Online hot-backup (SQLite / MariaDB) & R2 sync
│   ├── healthcheck.sh            # 5-tier diagnostic & network isolation verification
│   ├── restore_homelab.sh        # Point-in-time disaster recovery & validation
│   ├── rollback.sh               # Complete teardown and clean server reversion
│   ├── sync_notes_to_vault.sh    # Syncs git notes to live Obsidian/Flatnotes vault
│   └── update_vaultwarden.sh     # Minimal-downtime container updater
│
├── Caddyfile                      # dev1 root proxy configuration (backward compatibility)
├── docker-compose.yml             # dev1 root compose definition (backward compatibility)
├── .gitignore                     # Protects all .env files and runtime data directories
├── README.md                      # Central homelab overview
└── SETUP_AND_REPLICATION_GUIDE.md # Detailed replication and day-2 operations guide
```

---

## 📚 Knowledge Base & Flatnotes Web Editor

All infrastructure documentation, service guides, backup strategies, and disaster recovery runbooks are curated as an Obsidian-compliant knowledge vault in [`notes/`](file:///opt/homelab/notes/) and accessible via the **Flatnotes Web Editor** at `https://dev2.<tailnet>.ts.net:8083` or synced natively to Obsidian Desktop/Mobile via WebDAV.

| Section | Topic & Files |
| :--- | :--- |
| **Hub / Dashboard** | [`00 - Homelab Hub.md`](file:///opt/homelab/notes/00%20-%20Homelab%20Hub.md) — Master Map of Content, Service Directory & Status |
| **01 - Architecture** | [`00 - Architecture MOC.md`](file:///opt/homelab/notes/01%20-%20Architecture%20&%20Infrastructure/00%20-%20Architecture%20MOC.md), Topology, Server Specs, Tailscale Mesh, Caddy Ingress, Security Model |
| **02 - Services** | [`00 - Services MOC.md`](file:///opt/homelab/notes/02%20-%20Services/00%20-%20Services%20MOC.md), Vaultwarden, AdGuard Home, Uptime Kuma, Firefly Core, Importer, Obsidian Sync, Beszel |
| **03 - Operations** | [`00 - Operations MOC.md`](file:///opt/homelab/notes/03%20-%20Operations%20&%20Guides/00%20-%20Operations%20MOC.md), Maintenance SOPs, Telegram/Pushover Alerting, Obsidian Client Setup, Beszel Multi-Node |
| **04 - Disaster Recovery** | [`00 - Disaster Recovery MOC.md`](file:///opt/homelab/notes/04%20-%20Disaster%20Recovery%20&%20Backups/00%20-%20Disaster%20Recovery%20MOC.md), Cloudflare R2 Sync, Bare-Metal Restore, `dev1` Runbook, `dev2` Runbook, Live Drill Protocol |
| **Templates** | Reusable templates for new Services, Guides, DR Runbooks, and Architecture Specs |

---

## 🚀 Quick Deployment Guide

### Deploying on `dev1` (Core Stack)
```bash
# Automated deployment (recommended):
sudo bash scripts/deploy_stack.sh

# Or manual deployment:
cd /opt/homelab/hosts/dev1
cp .env.example .env      # Set passwords / domain variables
docker compose up -d
```
- **Vaultwarden**: `https://dev1.<tailnet>.ts.net`
- **AdGuard Home**: `https://dev1.<tailnet>.ts.net:8081`
- **Uptime Kuma**: `https://dev1.<tailnet>.ts.net:3001`

### Deploying on `dev2` (Firefly III, Obsidian & Beszel Monitoring)
```bash
# Automated deployment (recommended):
sudo bash scripts/deploy_stack.sh dev2

# Or manual deployment:
cd /opt/homelab/hosts/dev2
cp .env.example .env      # Generates APP_KEY, DB_PASSWORD, AUTO_IMPORT_SECRET
docker compose up -d

# Enable Tailscale Serve (HTTPS termination)
sudo tailscale serve --bg --https=443 http://127.0.0.1:8080
sudo tailscale serve --bg --https=8443 http://127.0.0.1:8081
sudo tailscale serve --bg --https=8082 http://127.0.0.1:8082
sudo tailscale serve --bg --https=8083 http://127.0.0.1:8083
sudo tailscale serve --bg --https=8090 http://127.0.0.1:8090
```
- **Firefly III Core**: `https://dev2.<tailnet>.ts.net`
- **Firefly Data Importer**: `https://dev2.<tailnet>.ts.net:8443`
- **Obsidian WebDAV Sync**: `https://dev2.<tailnet>.ts.net:8082/data/`
- **Obsidian Flatnotes Web**: `https://dev2.<tailnet>.ts.net:8083`
- **Beszel Server Health Hub**: `https://dev2.<tailnet>.ts.net:8090`

---

## ⚙️ Service Access & First-Time Configuration

### Step 1: Enable Tailscale MagicDNS & Free HTTPS
1. Go to your **[Tailscale Admin Console → DNS](https://login.tailscale.com/admin/dns)**.
2. Ensure **MagicDNS** is toggled **ON**.
3. Under **HTTPS Certificates**, toggle **Enable HTTPS**.

### Step 2: Access & Setup Applications
From any device (laptop, phone) connected to your Tailscale network:

| Host | Service | Access URL | Initial Setup Action |
| :--- | :--- | :--- | :--- |
| **dev1** | **Vaultwarden** | `https://dev1.<tailnet>.ts.net` | Create master password account & link Bitwarden apps. |
| **dev1** | **AdGuard Home** | `https://dev1.<tailnet>.ts.net:8081` | Complete wizard (port 80/53) & upstream DNS (Cloudflare DoH). |
| **dev1** | **Uptime Kuma** | `https://dev1.<tailnet>.ts.net:3001` | Create admin account & configure alert notifications. |
| **dev2** | **Firefly III Core** | `https://dev2.<tailnet>.ts.net` | Set up initial financial accounts and budgets. |
| **dev2** | **Firefly Data Importer** | `https://dev2.<tailnet>.ts.net:8443` | Enter Personal Access Token & import bank statements. |
| **dev2** | **Obsidian WebDAV** | `https://dev2.<tailnet>.ts.net:8082/data/` | Configure *Remotely Save* plugin in Obsidian Desktop / Mobile. |
| **dev2** | **Obsidian Web Editor** | `https://dev2.<tailnet>.ts.net:8083` | Log in with `obsidian` to view and edit notes in browser. |
| **dev2** | **Beszel Health Hub** | `https://dev2.<tailnet>.ts.net:8090` | Create admin account & link systems via `/beszel_socket/beszel.sock`. |

---

## 🛠️ Operations & Automation Scripts

The [`scripts/`](scripts/) directory contains a full suite of automation tools:

| Script | Purpose | Key Details |
| :--- | :--- | :--- |
| [`deploy_stack.sh`](scripts/deploy_stack.sh) | **Automated Setup** | Prepares systemd-resolved, Docker, Tailscale, generates TLS configs, and starts stack. |
| [`healthcheck.sh`](scripts/healthcheck.sh) | **5-Tier Diagnostics** | Tests Tailscale mesh, Docker containers, HTTPS / DNS endpoints, WAN port isolation, and RAM/disk. |
| [`backup_homelab.sh`](scripts/backup_homelab.sh) | **Automated Backups** | Online hot-backup (SQLite/MariaDB), archives configs & `.env` (`0600`), 14-day auto-rotation, R2 sync. |
| [`restore_homelab.sh`](scripts/restore_homelab.sh) | **Disaster Recovery** | Point-in-time state extraction, SQLite / SQL integrity validation, supports dry-run isolated testing. |
| [`update_vaultwarden.sh`](scripts/update_vaultwarden.sh) | **Zero-Downtime Updates** | Pre-pulls new layers while running, takes safety SQLite snapshot, hot-swaps container (~1-2s). |
| [`rollback.sh`](scripts/rollback.sh) | **Complete Teardown** | Stops containers, purges Docker & Tailscale, restores system DNS, and wipes `/opt/homelab`. |

---

## 🔒 Security Model
- **Zero Public Port Exposure**: All endpoints bind strictly to `127.0.0.1` or the private Tailscale interface (`100.64.0.0/10`).
- **Free Automated TLS**: Endpoints use automated Let's Encrypt certificates managed seamlessly via Tailscale MagicDNS (`*.ts.net`).
- **RAM-Tuned**: Strict Docker memory limits and MySQL/MariaDB performance optimization prevent OOM crashes on 1 GB RAM instances.
