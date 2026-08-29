---
title: "Guide: Beszel Multi-Node Monitoring Setup"
type: guide
category: monitoring
host: multi-host
status: active
tags:
  - homelab/guide
  - category/monitoring
  - beszel
  - telemetry
aliases:
  - Beszel Setup Guide
  - Multi-Node Monitoring
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Operations MOC|🛠️ Operations]] ➔ **Beszel Multi-Node Setup**

# 📊 Guide: Beszel Multi-Node Monitoring Setup

This guide provides step-by-step instructions for connecting both local (`dev2`) and remote (`dev1`) nodes to the central **Beszel Hub** dashboard.

---

## 🌐 Hub Overview & Access

- **Web Dashboard:** `https://dev2.<tailnet>.ts.net:8090`
- **Hub Host:** `dev2` (Local Unix Domain Socket + Tailscale Serve)
- **Agent Nodes:** `dev2` (local socket), `dev1` (TCP port 45876 over Tailscale WireGuard)

---

## 🖥️ 1. Adding `dev2` (Local Node via Unix Domain Socket)

The `dev2` agent communicates directly with the hub using a Unix Domain Socket (zero open host network ports).

### Steps in Web UI:
1. Open `https://dev2.<tailnet>.ts.net:8090`.
2. Click **"Add System"** (top right).
3. Enter settings:
   - **Name:** `dev2`
   - **Host / IP:** `/beszel_socket/beszel.sock`
   - **Port:** `45876` *(ignored when Unix socket is provided)*
   - **Public Key:** *(Auto-populated)*
4. Click **"Add"**. Real-time metrics streaming begins immediately!

---

## 🖥️ 2. Adding `dev1` (Remote Node over Tailscale)

### Step A: Start Agent on `dev1`
Ensure `beszel_agent` is running on `dev1` with the Hub's Ed25519 Public Key:
```bash
# On dev1:
cd /opt/homelab
echo 'BESZEL_KEY="ssh-ed25519 <YOUR_BESZEL_HUB_PUBLIC_KEY>"' >> .env
docker compose up -d beszel_agent
```

### Step B: Add System in Beszel Web UI
1. Open `https://dev2.<tailnet>.ts.net:8090`.
2. Click **"Add System"**.
3. Enter settings:
   - **Name:** `dev1`
   - **Host / IP:** `<dev1-tailscale-ip>` (or `dev1.<tailnet>.ts.net`)
   - **Port:** `45876`
   - **Public Key:** Match the public key shown on the screen.
4. Click **"Add"**.

---

## 🛠️ Troubleshooting "Unavailable" Node Status

| Issue | Cause | Fix |
| :--- | :--- | :--- |
| **Agent Exited (1)** | Missing `KEY` or `BESZEL_KEY` env variable | Supply Ed25519 public key in `.env` or `-e KEY="..."` |
| **Connection Timeout** | Host firewall blocking port 45876 on `tailscale0` | Run `sudo ufw allow in on tailscale0 to any port 45876 proto tcp` on `dev1` |
| **Socket Permission** | Hub or Agent cannot access socket directory | Verify `/opt/homelab/data/dev2/beszel/socket` is mounted rw |

---

## 🔗 Related Notes
- [[Service - Beszel Server Monitoring|Beszel Service Documentation]]
- [[Service - Uptime Kuma|Uptime Kuma Service Guide]]
- [[Disaster Recovery Runbook - dev2|dev2 Disaster Recovery Runbook]]
