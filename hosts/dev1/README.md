# Host: dev1 (Core Homelab Stack)

## Services
- **Vaultwarden**: Bitwarden-compatible password manager (`https://dev1.<tailnet>.ts.net`)
- **AdGuard Home**: Network-wide ad & tracker blocking DNS (`https://dev1.<tailnet>.ts.net:8081`)
- **Obsidian WebDAV**: Encrypted WebDAV server for cross-device Obsidian notes sync (`https://dev1.<tailnet>.ts.net:8082/data/`)
- **Caddy**: Reverse proxy with automatic Tailscale TLS certificates
- **Beszel Agent**: Lightweight host resource & Docker container metric collector (Port 45876)

## Deployment
```bash
cd /opt/homelab/hosts/dev1
cp .env.example .env
# Set BESZEL_KEY from your dev2 Beszel Hub ("Add System" dialog)
docker compose up -d
```

### Adding `dev1` to Beszel Hub Dashboard (on `dev2`):
1. Open Beszel Hub on `dev2`: `https://dev2.<tailnet>.ts.net:8090`
2. Click **"Add System"**:
   - **Name**: `dev1`
   - **Host / IP**: `<dev1-tailscale-ip>` (or `dev1.<tailnet>.ts.net`)
   - **Port**: `45876`
   - **Public Key**: Copy the displayed public key into `BESZEL_KEY` in `hosts/dev1/.env`.
3. Click **"Add"**.

---

## 🛠️ Operations & Disaster Recovery

### Healthcheck
```bash
sudo bash /opt/homelab/scripts/healthcheck.sh dev1
```

### Automated Live Backup & Cloudflare R2 Off-Site Sync
```bash
sudo bash /opt/homelab/scripts/backup_homelab.sh dev1
```

### Disaster Recovery Restore & Cloudflare R2 Drill
```bash
# 1. Restore from local backup archive:
sudo bash /opt/homelab/scripts/restore_homelab.sh --latest

# 2. Pull directly from Cloudflare R2 encrypted vault and restore:
rclone copy r2-crypt:<backup_filename>.tar.gz /opt/homelab/data/backups/ --config /opt/homelab/data/rclone/rclone.conf
sudo bash /opt/homelab/scripts/restore_homelab.sh --latest

# 3. Execute automated catastrophic failure & recovery drill:
sudo bash /opt/homelab/scripts/test_disaster_recovery.sh
```

