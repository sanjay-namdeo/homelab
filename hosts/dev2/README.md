# Host: dev2 (Personal Finance & Data Hub)

A production-grade, resource-efficient personal finance stack deployed on the `dev2` homelab node, optimized to run reliably within a 1 GB RAM server constraint.

---

## 🏛️ Services & Topology

| Service | Container Name | Internal Port | Tailscale Endpoint | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Firefly III Core** | `firefly_app` | `127.0.0.1:8080` | `https://dev2.<tailnet>.ts.net` (Port 443) | Self-hosted financial manager & double-entry accounting |
| **Firefly Data Importer** | `firefly_importer` | `127.0.0.1:8081` | `https://dev2.<tailnet>.ts.net:8443` (Port 8443) | Official statement & CSV import utility |
| **MariaDB 11.4 LTS** | `firefly_db` | `3306` (Internal) | *Internal Docker Network Only* | Low-memory tuned relational database |
| **Tailscale Serve** | Native Daemon | N/A | Ports 443 & 8443 | Automatic Let's Encrypt TLS termination via MagicDNS |

---

## 🔒 Security & Network Isolation Model

- **Zero WAN/LAN Exposure**: All container ports (`8080`, `8081`, `3306`) bind strictly to `127.0.0.1` or the internal bridge network `firefly_net`. External network interfaces (`ens3` / WAN) expose **zero open ports**.
- **Tailscale TLS Termination**: Encrypted ingress is handled natively by `tailscale serve`, providing valid Let's Encrypt certificates for both port 443 (Core) and port 8443 (Importer).
- **Hard Resource Limits**:
  - `firefly_app`: Max 384 MB RAM / 1.0 vCPU
  - `firefly_importer`: Max 256 MB RAM / 0.75 vCPU
  - `firefly_db`: Max 256 MB RAM / 0.75 vCPU
  - *Stack Idle Footprint*: ~40–50 MB total RAM across all three containers.

---

## 🚀 Deployment & Initialization

```bash
cd /opt/homelab/hosts/dev2

# 1. Initialize environment file (if first time)
cp .env.example .env
chmod 600 .env

# 2. Launch Docker stack
docker compose up -d

# 3. Enable Tailscale Serve HTTPS reverse proxies
sudo tailscale serve --bg --https=443 http://127.0.0.1:8080
sudo tailscale serve --bg --https=8443 http://127.0.0.1:8081
```

---

## 📥 Firefly III Data Importer Setup & Workflow

### 1. Generating Personal Access Token
1. Log in to Firefly III Core: `https://dev2.<tailnet>.ts.net`
2. Go to **Profile** ➔ **OAuth** ➔ **Personal Access Tokens**.
3. Click **Create New Token**, name it (e.g. `Data Importer`), and copy the generated token.

### 2. Accessing the Importer
1. Open `https://dev2.<tailnet>.ts.net:8443` in your browser.
2. Enter your Personal Access Token (or pre-configure `FIREFLY_III_ACCESS_TOKEN` in `hosts/dev2/.env`).
3. Upload CSV, CAMT.053, or bank export files to begin mapping and importing transactions.

### 3. Auto-Import Directory
Files dropped into `/opt/homelab/data/dev2/firefly/import` can be processed automatically via CLI or the auto-import endpoint using `AUTO_IMPORT_SECRET`.

---

## 🛠️ Operational Commands

### Health & Diagnostic Check
```bash
sudo bash /opt/homelab/scripts/healthcheck.sh --host dev2
```

### Automated Live Backup & Cloudflare R2 Off-Site Sync
```bash
sudo bash /opt/homelab/scripts/backup_homelab.sh --host dev2
```
*Creates an atomic MariaDB hot dump + Firefly uploads archive, restricts permissions (`0600`), prunes local backups older than 14 days, and syncs encrypted snapshots to Cloudflare R2 (`r2-crypt:`).*

### Automated Daily Backup Timer (Runs Daily at 03:00 UTC)
```bash
# Check timer status
systemctl status homelab-backup.timer
systemctl list-timers homelab-backup.timer
```

### Disaster Recovery Restore
```bash
# From local backup
sudo bash /opt/homelab/scripts/restore_homelab.sh /opt/homelab/data/backups/homelab_backup_dev2_<timestamp>.tar.gz

# Or pull latest encrypted backup from Cloudflare R2
sudo rclone copy r2-crypt:<backup_name>.tar.gz /opt/homelab/data/backups/ --config /opt/homelab/data/rclone/rclone.conf
sudo bash /opt/homelab/scripts/restore_homelab.sh /opt/homelab/data/backups/<backup_name>.tar.gz
```
