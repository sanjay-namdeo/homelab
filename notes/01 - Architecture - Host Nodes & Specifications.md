---
title: "Host Nodes & Server Specifications"
type: architecture
category: architecture
host: multi-host
status: active
tags:
  - homelab/architecture
  - host/dev1
  - host/dev2
  - hardware
aliases:
  - Server Specs
  - Node Specifications
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Architecture MOC|📐 Architecture]] ➔ **Host Nodes & Server Specifications**

# 🖥️ Host Nodes & Server Specifications

This document outlines the hardware specifications, container allocations, resource ceilings, and storage volume mappings across both homelab nodes.

---

## 🖥️ Node: `dev1` (Security, DNS & Ingress Hub)

- **Operating System:** Ubuntu 24.04 LTS (x86_64 / ARM64)
- **Role:** Password management, network ad-blocking DNS, uptime monitoring, and TLS reverse proxy.
- **Tailscale IP:** `<dev1-tailscale-ip>`
- **Tailscale Hostname:** `dev1.<tailnet>.ts.net`

### Container Resource Allocation (`dev1`)

| Container | Image | Memory Limit | CPU Limit | Idle RAM Usage |
| :--- | :--- | :--- | :--- | :--- |
| `caddy` | `caddy:alpine` | 64 MB | 0.50 vCPU | ~15 MB |
| `vaultwarden` | `vaultwarden/server:alpine` | 128 MB | 0.50 vCPU | ~25 MB |
| `adguardhome` | `adguard/adguardhome:latest` | 128 MB | 0.50 vCPU | ~35 MB |
| `uptime-kuma` | `louislam/uptime-kuma:1` | 128 MB | 0.50 vCPU | ~45 MB |
| `beszel_agent` | `henrygd/beszel-agent:latest` | 64 MB | 0.25 vCPU | ~8 MB |
| **Total Target**| | **512 MB Max** | | **~128 MB Idle** |

---

## 🖥️ Node: `dev2` (Finance, Knowledge & System Health Hub)

- **Operating System:** Ubuntu 24.04 LTS (x86_64 / ARM64)
- **Role:** Personal finance bookkeeping, Markdown WebDAV sync, Flatnotes web wiki, and central Beszel monitoring hub.
- **Tailscale IP:** `<dev2-tailscale-ip>`
- **Tailscale Hostname:** `dev2.<tailnet>.ts.net`

### Container Resource Allocation (`dev2`)

| Container | Image | Memory Limit | CPU Limit | Idle RAM Usage |
| :--- | :--- | :--- | :--- | :--- |
| `firefly_db` | `mariadb:lts` (11.4 LTS) | 256 MB | 0.75 vCPU | ~65 MB |
| `firefly_app` | `fireflyiii/core:latest` | 384 MB | 1.00 vCPU | ~70 MB |
| `firefly_importer`| `fireflyiii/data-importer:latest` | 256 MB | 0.75 vCPU | ~45 MB |
| `obsidian_webdav`| `bytemark/webdav:latest` | 64 MB | 0.50 vCPU | ~5 MB |
| `obsidian_web` | `dullage/flatnotes:latest` | 128 MB | 0.50 vCPU | ~48 MB |
| `beszel` | `henrygd/beszel:latest` | 128 MB | 0.50 vCPU | ~18 MB |
| `beszel_agent` | `henrygd/beszel-agent:latest` | 64 MB | 0.25 vCPU | ~8 MB |
| **Total Target**| | **1280 MB Max** | | **~259 MB Idle** |

---

## 💾 Storage Volume Directory Structure

```text
/opt/homelab/
├── hosts/
│   ├── dev1/                      # dev1 stack configuration & secrets
│   └── dev2/                      # dev2 stack configuration & secrets
├── data/
│   ├── vaultwarden/               # dev1: SQLite DB & RSA keys
│   ├── adguard/                   # dev1: YAML configuration & filter lists
│   ├── uptime-kuma/               # dev1: SQLite metrics & notifications
│   ├── caddy/                     # dev1: TLS certificates & state
│   ├── dev2/
│   │   ├── firefly/
│   │   │   ├── db/                # dev2: MariaDB relational engine data
│   │   │   ├── upload/            # dev2: Attached receipts & invoices
│   │   │   └── import/            # dev2: CSV/CAMT import staging
│   │   ├── obsidian/
│   │   │   ├── vault/             # dev2: Markdown notes & assets
│   │   │   └── flatnotes_data/    # dev2: Flatnotes search index
│   │   └── beszel/
│   │       ├── data/              # dev2: Time-series metrics & SSH keys
│   │       └── socket/            # dev2: IPC Unix domain socket
│   └── backups/                   # Timestamped .tar.gz archives (0600)
```

---

## 🔗 Related Notes
- [[Homelab Architecture & Topology|Homelab Architecture & Topology]]
- [[Network & Tailscale WireGuard Mesh|Tailscale WireGuard Mesh]]
- [[Guide - Operations, Maintenance & Troubleshooting|Operations & Troubleshooting Guide]]
