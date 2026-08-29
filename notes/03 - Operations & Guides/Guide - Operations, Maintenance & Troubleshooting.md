---
title: "Guide: Operations, Maintenance & Troubleshooting"
type: guide
category: operations
host: multi-host
status: active
tags:
  - homelab/guide
  - category/operations
  - troubleshooting
  - maintenance
aliases:
  - Operations Guide
  - Troubleshooting Manual
  - Maintenance SOP
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Operations MOC|🛠️ Operations]] ➔ **Operations & Troubleshooting**

# 🛠️ Guide: Operations, Maintenance & Troubleshooting

This operations manual provides standard operating procedures for routine maintenance, healthcheck diagnostics, container updates, and troubleshooting common failure modes across `dev1` and `dev2`.

---

## 🔍 Running Diagnostic Health Checks

Our comprehensive diagnostic suite checks network interfaces, Tailscale connectivity, container health, loopback bindings, database integrity, file permissions, and backup freshness.

```bash
# Run on dev1 or dev2
sudo bash /opt/homelab/scripts/healthcheck.sh
```

### What the Healthcheck Tests:
- [x] Tailscale connection state and MagicDNS FQDN.
- [x] Docker container status and container healthcheck outcomes.
- [x] Endpoints availability (HTTP, HTTPS via Tailscale Serve / Caddy, DNS port 53).
- [x] WAN/LAN port isolation (ensuring ports 8080, 8081, 8082, 8083, 8090, 3306 are not exposed to public/LAN interfaces).
- [x] File permission security (`0600` on `.env`, `0700` on DB directories).
- [x] Backup freshness (< 24 hours old).
- [x] System resource utilization (RAM, Swap, Disk).

---

## 🔄 Container Upgrade Procedures

### 1. Standard Multi-Container Update
```bash
cd /opt/homelab/hosts/dev2  # Or dev1
docker compose pull
docker compose up -d
```

### 2. Zero-Downtime Hot Upgrade (Vaultwarden)
For critical services like Vaultwarden, run the dedicated updater which takes a pre-upgrade safety SQLite snapshot, pulls layers in the background, and hot-swaps the container in ~1-2 seconds:
```bash
sudo bash /opt/homelab/scripts/update_vaultwarden.sh
```

---

## 🛠️ Common Troubleshooting Scenarios

### Scenario 1: Tailscale Serve Returns 502 Bad Gateway
- **Cause:** Underlying backend container is down or restarting.
- **Fix:**
  ```bash
  docker ps -a
  docker logs --tail 50 <container_name>
  docker compose up -d <container_name>
  ```

### Scenario 2: Flatnotes Search Not Finding New Files
- **Cause:** Flatnotes search index cache needs a refresh.
- **Fix:**
  ```bash
  sudo bash /opt/homelab/scripts/sync_notes_to_vault.sh
  ```

### Scenario 3: MariaDB Memory Spike on 1GB RAM Instance
- **Cause:** InnoDB buffer pool or performance schema consuming too much RAM.
- **Fix:** Verify `hosts/dev2/docker-compose.yml` includes:
  `command: --innodb-buffer-pool-size=128M --performance_schema=OFF --max-connections=50`

---

## 🔗 Related Notes
- [[Guide - Notifications & Alerting (Telegram, Pushover, Email)|Alerting Configuration Guide]]
- [[Disaster Recovery Runbook - dev1|dev1 Disaster Recovery Runbook]]
- [[Disaster Recovery Runbook - dev2|dev2 Disaster Recovery Runbook]]
