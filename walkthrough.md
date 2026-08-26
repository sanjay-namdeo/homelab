# Walkthrough: Personal Cloud & Privacy Hub Verification

## Verification & Health Check Summary

All components are active, healthy, and verified operational across reboots:

```
COMPONENT               SERVICE STATUS    PORT BINDINGS                          HEALTH / USAGE
Tailscale               active (running)  Tailnet mesh (WireGuard)               Connected (Exit Node + SSH)
AdGuard Home            Up (healthy)      <tailscale-ip>:53, :8081               Parallel DoH Active (Isolated)
Vaultwarden             Up (healthy)      127.0.0.1:8080                         TLS 1.3 Active (Signups Disabled)
Caddy Reverse Proxy     Up (healthy)      0.0.0.0:80, 0.0.0.0:443                Tailscale TLS Automated
Healthcheck Diagnostic  Executable        /opt/homelab/scripts/healthcheck.sh    100% PASS (5/5 checks)
Automated Deploy Script Executable        /opt/homelab/scripts/deploy_stack.sh   Syntax & logic PASSED
Replication Guide       Saved             /opt/homelab/SETUP_AND_REPLICATION_GUIDE.md Complete & Verified
Rollback Script         Executable        /opt/homelab/scripts/rollback.sh       Syntax & logic PASSED
```

---

## 🛠️ Operations & Automation Scripts Reference

| Script | Path | Description |
| :--- | :--- | :--- |
| **Stack Deployment** | [`scripts/deploy_stack.sh`](scripts/deploy_stack.sh) | 1-command deployment configuring systemd-resolved, Docker, Tailscale, Caddy TLS, and compose stack. |
| **Health Diagnostics** | [`scripts/healthcheck.sh`](scripts/healthcheck.sh) | 5-tier testing of Tailscale, containers, HTTP/DNS endpoints, WAN port isolation, and resource usage. |
| **Automated Backups** | [`scripts/backup_homelab.sh`](scripts/backup_homelab.sh) | Atomic point-in-time SQLite hot-backup, AdGuard/Caddy configs & `.env` archive (`0600`) with 14-day rotation. |
| **Vaultwarden Updater**| [`scripts/update_vaultwarden.sh`](scripts/update_vaultwarden.sh) | Zero-downtime layer pre-pulling, SQLite safety snapshot, hot container recreation (~1-2s). |
| **Teardown / Rollback**| [`scripts/rollback.sh`](scripts/rollback.sh) | Full uninstallation, Docker/Tailscale purge, system DNS restoration, and directory cleanup. |

---

## 🔄 Host Restart & Reboot Procedures

### Automatic Reboot Persistence
All services automatically restart on host boot (`restart: unless-stopped` + systemd).
1. `systemd-resolved` automatically bypasses port 53 stub listener.
2. `tailscaled` reconnects WireGuard mesh and re-enables Exit Node routing.
3. Containers automatically spin up and reconnect to the Tailscale socket.

### Post-Reboot Verification
Allow **10–15 seconds** for upstream DoH connections to warm up, then run:
```bash
sudo bash /opt/homelab/scripts/healthcheck.sh
```

---

## 🚀 Fast Replication Summary (On Any New Server)

### Step 1: Deploy Homelab Stack
```bash
sudo git clone git@github.com:sanjay-namdeo/homelab.git /opt/homelab
cd /opt/homelab
sudo bash scripts/deploy_stack.sh
```

### Step 2: Access Endpoints
- **Vaultwarden (Passwords)**: `https://<node>.<tailnet>.ts.net`
- **AdGuard Home (Dashboard)**: `http://<tailscale-ip>:8081` *(or `:3000` during first-time wizard)*

> 📖 **Complete Documentation**:
> Refer to [`SETUP_AND_REPLICATION_GUIDE.md`](SETUP_AND_REPLICATION_GUIDE.md) for full step-by-step instructions, Tailscale DNS/Exit node setup, client bypass fixes, and backup/restore workflows.

