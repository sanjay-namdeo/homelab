---
title: "Homelab Architecture & Topology Overview"
type: architecture
category: architecture
host: multi-host
status: active
tags:
  - homelab/architecture
  - architecture/topology
  - networking
  - host/multi-host
aliases:
  - Homelab Topology
  - Infrastructure Blueprint
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Architecture MOC|📐 Architecture]] ➔ **Homelab Architecture & Topology**

# 🗺️ Homelab Architecture & Topology

This document details the multi-node infrastructure topology, communication flows between client devices and servers, and service mapping across nodes.

---

## 🏗️ Multi-Host Structural Design

The homelab distributes services across two distinct Ubuntu hosts to balance workload, isolate critical security functions, and stay well within memory constraints (designed for 1 GB RAM nodes):

1. **`dev1` (Edge Security, Ingress & DNS)**:
   - Hosts authentication (Vaultwarden), DNS ad-blocking (AdGuard Home), and active uptime probing (Uptime Kuma).
   - Serves as the primary ingress point using Caddy Reverse Proxy.
2. **`dev2` (Finance, Knowledge Base & System Health Hub)**:
   - Hosts personal finance bookkeeping (Firefly III & Importer with MariaDB).
   - Hosts the Obsidian sync backend (WebDAV) and browser wiki (Flatnotes).
   - Hosts the central Beszel health monitoring telemetry hub.

---

## 📊 End-to-End System Topology Diagram

```mermaid
graph TD
    subgraph ClientDevices ["📱 Client Devices (Laptop / Phone / Tablet)"]
        Browser["🌐 Web Browser"]
        BitwardenApp["🔑 Bitwarden Client"]
        ObsidianApp["📝 Obsidian App (Remotely Save)"]
        DNSClient["🛡️ System DNS Resolver"]
    end

    subgraph TailscaleMesh ["🔐 Encrypted Tailscale WireGuard Mesh (*.ts.net)"]
        MagicDNS["Tailscale MagicDNS & Automatic Let's Encrypt TLS"]
    end

    subgraph NodeDev1 ["🖥️ dev1 (Security, DNS & Ingress Hub)"]
        Caddy["⚡ Caddy Reverse Proxy (:80 / :443 TLS)"]
        VW["🔑 Vaultwarden (:8080)"]
        AG["🛡️ AdGuard Home (:53 DNS, :8081 Web)"]
        UK["📊 Uptime Kuma (:3001)"]
        BA1["📈 Beszel Agent (:45876)"]
    end

    subgraph NodeDev2 ["🖥️ dev2 (Finance, Knowledge & Health Hub)"]
        TS2["⚡ Tailscale Serve (TLS Ports 443, 8443, 8082, 8083, 8090)"]
        FF["💰 Firefly III Core (:8080)"]
        FFI["📥 Firefly Data Importer (:8081)"]
        MDB["🗄️ MariaDB 11.4 LTS (:3306)"]
        WD["🔄 Obsidian WebDAV (:8082)"]
        FN["📝 Obsidian Flatnotes Web (:8083)"]
        BH["📊 Beszel Hub (:8090)"]
        BA2["📈 Beszel Agent (Unix Socket)"]
    end

    subgraph OffsiteBackup ["☁️ Cloudflare R2 (Off-Site Backup)"]
        R2["🪣 Encrypted Snapshot Storage (rclone)"]
    end

    Browser <-->|Encrypted WireGuard HTTPS| MagicDNS
    BitwardenApp <-->|HTTPS API / Sync| MagicDNS
    ObsidianApp <-->|HTTPS WebDAV Sync| MagicDNS
    DNSClient -.->|Port 53 DNS Queries| AG

    MagicDNS <--> Caddy
    MagicDNS <--> TS2

    Caddy --> VW
    Caddy --> AG
    Caddy --> UK

    TS2 --> FF
    TS2 --> FFI
    TS2 --> WD
    TS2 --> FN
    TS2 --> BH

    FF --> MDB
    FFI --> FF
    WD --> FN
    BH -.->|IPC Socket| BA2
    BH -.->|Tailscale :45876| BA1

    NodeDev1 -.->|Nightly Backup Snapshots| OffsiteBackup
    NodeDev2 -.->|Nightly Backup Snapshots| OffsiteBackup
```

---

## 🔒 Key Design Tenets

1. **Zero Open Public Ports**: No ports are open to the public Internet. WAN ingress is 100% blocked.
2. **Encrypted Transport Layer**: All traffic flows through WireGuard tunnels with ChaCha20-Poly1305 authenticated encryption.
3. **Automated Trusted TLS**: Real Let's Encrypt certificates managed automatically via Tailscale MagicDNS.
4. **Hard Memory Caps**: Every container enforces CPU and memory limits to prevent out-of-memory kernel panics.

---

## 🔗 Related Notes & Runbooks
- [[Host Nodes & Server Specifications|Host Nodes Specifications]]
- [[Network & Tailscale WireGuard Mesh|Tailscale Mesh Networking]]
- [[00 - Services MOC|Core Services Directory]]
- [[Guide - Backup & Off-Site Sync (Cloudflare R2)|Backup Strategy]]
