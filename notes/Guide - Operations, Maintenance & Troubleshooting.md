# 🛠️ Guide: Operations, Maintenance & Troubleshooting

This operations manual provides routine maintenance schedules, diagnostic procedures, container upgrade workflows, and solutions to common homelab operational issues.

---

## 📅 Routine Maintenance Schedule

| Frequency | Task | Command / Procedure |
| :--- | :--- | :--- |
| **Daily** | Automated Point-in-Time Backup | Managed automatically via cron (`scripts/backup_homelab.sh`) |
| **Weekly** | Health Diagnostic Check | `sudo bash /opt/homelab/scripts/healthcheck.sh` |
| **Monthly** | Host Security Updates | `sudo apt update && sudo apt upgrade -y` |
| **Monthly** | Docker Image Updates | Pull latest stable images and verify health |
| **Quarterly**| Off-Site Disaster Recovery Drill | Test restoring snapshot to a test environment |

---

## 🔍 Running Diagnostics & Health Checks

Our comprehensive diagnostic suite checks network interfaces, Tailscale connectivity, container health, ports, database integrity, file permissions, and backup freshness.

```bash
# Run on dev1 or dev2
sudo bash /opt/homelab/scripts/healthcheck.sh

# Run specifically targeting dev1
sudo bash /opt/homelab/scripts/healthcheck.sh --host dev1

# Run specifically targeting dev2
sudo bash /opt/homelab/scripts/healthcheck.sh --host dev2
```

### Healthcheck Categories Covered:
1. **Tailscale Network Mesh:** Daemon running, IP assigned, MagicDNS FQDN active.
2. **Docker Container States:** Containers running, restart policies, zero unhealthy states.
3. **Network Ingress & Port Bindings:** Port 80/443/53/8081/8082/8083/8090/45876.
4. **Security & Permissions:** `.env` is `0600`, zero exposed ports on WAN.
5. **Database Integrity:** SQLite `PRAGMA integrity_check` & MariaDB connection.
6. **Resource Consumption:** CPU load, RAM usage under 85%, disk space headroom.
7. **Backup Verification:** Local snapshot exists and is under 26 hours old.

---

## 🔄 Upgrading Docker Images & Services

### Upgrading `dev1` Services (Vaultwarden, AdGuard, Uptime Kuma, Caddy)
```bash
cd /opt/homelab

# 1. Create a pre-upgrade safety snapshot
sudo bash scripts/backup_homelab.sh --host dev1

# 2. Pull latest container images
docker compose pull

# 3. Recreate containers with new images
docker compose up -d

# 4. Verify system health
sudo bash scripts/healthcheck.sh
```

### Dedicated Vaultwarden Upgrade Script
```bash
sudo bash /opt/homelab/scripts/update_vaultwarden.sh
```
*This dedicated script pulls the newest Vaultwarden image, verifies database migrations, performs healthcheck probing, and automatically rolls back if the new container fails to initialize.*

### Upgrading `dev2` Services (Firefly III, WebDAV, Flatnotes, Beszel)
```bash
cd /opt/homelab/hosts/dev2

# 1. Create safety snapshot
sudo bash /opt/homelab/scripts/backup_homelab.sh --host dev2

# 2. Pull latest images
docker compose pull

# 3. Recreate stack
docker compose up -d

# 4. Run database migrations (if Firefly updated)
docker exec -it firefly_app php artisan migrate --force

# 5. Clear application cache
docker exec -it firefly_app php artisan cache:clear
```

---

## ⏪ Rollback Procedures

If an upgrade introduces regressions or fails to start:

```bash
# Automated rollback using latest backup snapshot
sudo bash /opt/homelab/scripts/rollback.sh
```

---

## 🩺 Common Troubleshooting Scenarios

### Scenario 1: Port 53 Already in Use on `dev1`
- **Symptom:** `adguardhome` container fails with `bind: address already in use` on port 53.
- **Cause:** Ubuntu's `systemd-resolved` stub listener is running on `127.0.0.53:53`.
- **Fix:**
  ```bash
  sudo mkdir -p /etc/systemd/resolved.conf.d/
  echo -e "[Resolve]\nDNS=1.1.1.1 8.8.8.8\nDNSStubListener=no" | sudo tee /etc/systemd/resolved.conf.d/adguard.conf
  sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
  sudo systemctl restart systemd-resolved
  cd /opt/homelab && docker compose restart adguardhome
  ```

---

### Scenario 2: Tailscale MagicDNS Certificate Errors
- **Symptom:** Browser warns of invalid or expired SSL certificate on `dev1.<tailnet>.ts.net`.
- **Fix:**
  ```bash
  # Check Tailscale daemon status
  sudo tailscale status
  
  # Restart Caddy to force certificate fetch
  docker compose restart caddy
  docker logs caddy | grep -i tls
  ```

---

### Scenario 3: Flatnotes File Permission Errors on `dev2`
- **Symptom:** Flatnotes web UI reports "Permission Denied" when saving or editing notes.
- **Cause:** Files created by root or external sync have mismatched ownership.
- **Fix:**
  ```bash
  sudo chown -R 82:82 /opt/homelab/data/dev2/obsidian
  sudo chmod -R 775 /opt/homelab/data/dev2/obsidian
  ```

---

### Scenario 4: High Memory / OOM Protection on 1GB VPS
- **Symptom:** Container randomly restarts or gets killed by Linux OOM Killer (`dmesg | grep -i oom`).
- **Fix:** All containers in `docker-compose.yml` include strict memory limits. Ensure kernel swapiness is tuned:
  ```bash
  sudo sysctl vm.swappiness=15
  sudo sysctl vm.vfs_cache_pressure=50
  ```

---

## 📜 Log Inspection Cheat Sheet

```bash
# Follow Caddy reverse proxy logs
docker logs -f caddy --tail 50

# Follow Vaultwarden authentication logs
docker logs -f vaultwarden --tail 50

# Follow Firefly III application errors
docker logs -f firefly_app --tail 50

# Follow Beszel agent telemetry logs
docker logs -f beszel_agent --tail 50

# System kernel logs for OOM or network drops
sudo dmesg -T | grep -E "oom|out of memory|killed"
```

---

## 🔗 Related Notes
- [[00 - Homelab Overview & Architecture|Homelab Overview]]
- [[Guide - Backup & Off-Site Sync|Homelab Backup & Snapshot Guide]]
- [[Guide - Disaster Recovery & Restore|Disaster Recovery & Restore Runbook]]
