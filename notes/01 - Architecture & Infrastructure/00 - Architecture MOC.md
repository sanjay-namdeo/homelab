---
title: "Architecture & Infrastructure Map of Content"
type: moc
category: architecture
host: multi-host
status: active
tags:
  - homelab
  - homelab/moc
  - architecture
  - networking
  - security
aliases:
  - Architecture MOC
  - Infrastructure Index
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ **Architecture & Infrastructure**

# 📐 Architecture & Infrastructure

The homelab is built upon a distributed, high-security, resource-optimized multi-node architecture running on Ubuntu LTS without public internet port exposure.

---

## 📑 Section Overview

- [[Homelab Architecture & Topology|Homelab Architecture & Topology]]
  *Complete architectural breakdown, client connectivity flow, and inter-service communications.*
- [[Host Nodes & Server Specifications|Host Nodes & Server Hardware Specs]]
  *System resource allocation, memory limits, storage layouts, and role division across `dev1` and `dev2`.*
- [[Network & Tailscale WireGuard Mesh|Tailscale WireGuard Mesh & MagicDNS]]
  *Private overlay network, CGNAT IP routing, MagicDNS resolution, and Tailscale Serve TLS termination.*
- [[Ingress & Caddy Reverse Proxy|Caddy Reverse Proxy & Automatic TLS]]
  *Native Caddy configuration on `dev1`, Unix socket communication with Tailscale daemon, and automated HTTPS.*
- [[Security Model & Threat Isolation|Zero-Trust Security & Threat Isolation]]
  *Port isolation, localhost-binding, least-privilege Docker containers, permission lockdown, and encrypted cloud replication.*

---

## 🏛️ Node Distribution Matrix

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Tailscale WireGuard Mesh (*.ts.net)                    │
├──────────────────────────────────────┬──────────────────────────────────────┤
│  dev1 (Edge Security & Monitoring)   │  dev2 (Finance, Wiki & Health Hub)   │
├──────────────────────────────────────┼──────────────────────────────────────┤
│  • Caddy Reverse Proxy (:80/:443)    │  • Tailscale Serve TLS Ingress       │
│  • Vaultwarden Server (:8080)        │  • Firefly III Core (:8080)          │
│  • AdGuard Home DNS (:53 / :8081)    │  • Firefly Data Importer (:8081)     │
│  • Uptime Kuma Monitor (:3001)       │  • MariaDB 11.4 Database (:3306)     │
│  • Beszel Monitoring Agent (:45876)  │  • Obsidian WebDAV Backend (:8082)   │
│                                      │  • Flatnotes Web Wiki (:8083)        │
│                                      │  • Beszel Monitoring Hub (:8090)     │
│                                      │  • Beszel Local Agent (Unix Socket)  │
└──────────────────────────────────────┴──────────────────────────────────────┘
```

---

## 🔗 Related Sections
- [[00 - Services MOC|📦 02 - Core Services]]
- [[00 - Operations MOC|🛠️ 03 - Operations & Guides]]
- [[00 - Disaster Recovery MOC|🚑 04 - Disaster Recovery & Backups]]
