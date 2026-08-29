---
title: "Service: Beszel (Server Health & Resource Monitoring)"
type: service
category: monitoring
host: dev2
status: active
tags:
  - homelab/service
  - category/monitoring
  - host/dev2
  - host/dev1
  - telemetry
  - beszel
aliases:
  - Beszel Monitoring
  - Beszel Hub
  - Server Telemetry
created: 2026-08-28
last_updated: 2026-08-29
url: "https://dev2.<tailnet>.ts.net:8090"
port: 8090
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Services MOC|📦 Services]] ➔ **Beszel Server Monitoring**

# 📈 Service: Beszel (Server Health & Resource Monitoring)

**Beszel** is an ultra-lightweight, real-time server resource monitoring hub and agent that tracks CPU, Memory, Swap, Disk I/O, Network throughput, host temperatures, and per-container Docker CPU/RAM utilization.

---

## 🏗️ Architecture & Deployment

Beszel operates on a Hub-and-Agent architecture:
- **Beszel Hub (`beszel`):** Deployed on `dev2` (Port `127.0.0.1:8090`, proxied via Tailscale Serve to `https://dev2.<tailnet>.ts.net:8090`). Stores time-series metrics in an embedded PocketBase database.
- **Beszel Agent (`beszel_agent` on `dev2`):** Communicates with the local Hub directly via a shared Unix Domain Socket (`/beszel_socket/beszel.sock`), eliminating host port exposure.
- **Beszel Agent (`beszel_agent` on `dev1`):** Listens on port `45876` bound to host network mode, allowing the Hub on `dev2` to query telemetry securely over the Tailscale WireGuard mesh.
- **Resource Footprint:** Hub uses ~15 MB RAM; Agent uses ~8 MB RAM.

```mermaid
graph TD
    User["👤 Browser (Admin)"] -->|HTTPS :8090| TS["⚡ Tailscale Serve (:8090)"]
    TS -->|HTTP :8090| Hub["📊 Beszel Hub (dev2)"]

    subgraph NodeDev2 ["🖥️ dev2 (Local Node)"]
        Hub <-->|UNIX Socket IPC (/beszel_socket/beszel.sock)| Agent2["📈 Beszel Agent (dev2)"]
    end

    subgraph NodeDev1 ["🖥️ dev1 (Remote Node)"]
        Hub <-->|Tailscale Mesh (Port 45876)| Agent1["📈 Beszel Agent (dev1)"]
    end
```

---

## 🖥️ Multi-Node Agent Setup

For step-by-step instructions on linking `dev1` and `dev2` and troubleshooting firewall issues:
👉 See [[Guide - Beszel Multi-Node Monitoring Setup|Beszel Multi-Node Monitoring Setup Guide]]

---

## 📊 Telemetry Metrics Tracked

- **Host Metrics:** Real-time CPU%, Load Average, RAM / Cache / Swap, Disk I/O, Network Throughput, CPU Temperature.
- **Docker Container Analytics:** Individual per-container CPU%, RAM usage, restart counts, and status.

---

## 💾 Backup & Data Protection

Beszel stores historical metrics and node credentials in PocketBase at `/opt/homelab/data/dev2/beszel/data`.
Archived daily by `scripts/backup_homelab.sh --host dev2`.

---

## 🔗 Related Notes
- [[Guide - Beszel Multi-Node Monitoring Setup|Beszel Multi-Node Setup Guide]]
- [[Service - Uptime Kuma|Uptime Kuma Monitor]]
- [[Disaster Recovery Runbook - dev2|dev2 Disaster Recovery Runbook]]
