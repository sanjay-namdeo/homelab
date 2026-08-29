# Host: dev2 (Finance, Knowledge Hub & Server Monitoring)

A production-grade, resource-efficient personal finance, Obsidian note-taking, and Beszel server health monitoring stack deployed on the `dev2` homelab node, optimized to run reliably within a 1 GB RAM server constraint.

---

## 🏛️ Services & Topology

| Service | Container Name | Internal Port | Tailscale Endpoint | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Firefly III Core** | `firefly_app` | `127.0.0.1:8080` | `https://dev2.<tailnet>.ts.net` (Port 443) | Self-hosted financial manager & double-entry accounting |
| **Firefly Data Importer** | `firefly_importer` | `127.0.0.1:8081` | `https://dev2.<tailnet>.ts.net:8443` (Port 8443) | Official statement & CSV import utility |
| **Obsidian WebDAV Sync** | `obsidian_webdav` | `127.0.0.1:8082` | `https://dev2.<tailnet>.ts.net:8082/data/` | High-performance WebDAV sync backend for Obsidian apps |
| **Obsidian Flatnotes Web** | `obsidian_web` | `127.0.0.1:8083` | `https://dev2.<tailnet>.ts.net:8083` (Port 8083) | Fast, lightweight browser markdown viewer & editor |
| **Beszel Hub Dashboard** | `beszel` | `127.0.0.1:8090` | `https://dev2.<tailnet>.ts.net:8090` (Port 8090) | Central lightweight server health & metrics dashboard |
| **Beszel Agent** | `beszel_agent` | Unix Socket | `IPC (/beszel_socket/beszel.sock)` | Host resource & Docker container metric collector |
| **MariaDB 11.4 LTS** | `firefly_db` | `3306` (Internal) | *Internal Docker Network Only* | Low-memory tuned relational database |
| **Tailscale Serve** | Native Daemon | N/A | Ports 443, 8443, 8082, 8083, 8090 | Automatic Let's Encrypt TLS termination via MagicDNS |

---

## 🔒 Security & Network Isolation Model

- **Zero WAN/LAN Exposure**: All container ports (`8080`, `8081`, `8082`, `8083`, `8090`, `3306`) bind strictly to `127.0.0.1` or the internal bridge network `firefly_net`. External network interfaces (`ens3` / WAN) expose **zero open ports**.
- **Unix Domain Socket IPC**: The local `beszel_agent` communicates directly with `beszel` Hub via a shared Unix domain socket (`/beszel_socket/beszel.sock`), eliminating host port exposure.
- **Tailscale TLS Termination**: Encrypted ingress is handled natively by `tailscale serve`, providing valid Let's Encrypt certificates across all ports.
- **Hard Resource Limits**:
  - `firefly_app`: Max 384 MB RAM / 1.0 vCPU
  - `firefly_importer`: Max 256 MB RAM / 0.75 vCPU
  - `firefly_db`: Max 256 MB RAM / 0.75 vCPU
  - `obsidian_webdav`: Max 64 MB RAM / 0.50 vCPU (~5 MB idle)
  - `obsidian_web`: Max 128 MB RAM / 0.50 vCPU (~50 MB idle)
  - `beszel`: Max 128 MB RAM / 0.50 vCPU (~15 MB idle)
  - `beszel_agent`: Max 64 MB RAM / 0.25 vCPU (~8 MB idle)
  - *Full Stack Idle Footprint*: ~130–150 MB total RAM across all seven containers.

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
sudo tailscale serve --bg --https=8082 http://127.0.0.1:8082
sudo tailscale serve --bg --https=8083 http://127.0.0.1:8083
sudo tailscale serve --bg --https=8090 http://127.0.0.1:8090
```

---

## 📱 Obsidian Tri-Platform Sync Configuration (Web, Mobile & Desktop)

### 1. Desktop & Mobile Sync Setup (PC / Mac / iOS / Android)
1. Open the **Obsidian** app on your device.
2. Go to **Settings ➔ Community Plugins ➔ Browse**.
3. Search for and install **Remotely Save** (by *fyears* / *sboersma*). Enable the plugin.
4. Open **Remotely Save Settings**:
   - **Sync Service**: Select `Webdav`.
   - **Server Address**: `https://dev2.<tailnet>.ts.net:8082/data/` (or `https://dev2.<tailnet>.ts.net:8082/data/`)
   - **Username**: `obsidian` (or configured `WEBDAV_USERNAME` in `.env`)
   - **Password**: Your `WEBDAV_PASSWORD` from `/opt/homelab/hosts/dev2/.env`
   - **Auth Type**: `Basic`
   - **Schedule**: Enable auto-sync on app startup, interval (e.g. every 5 minutes), or after note changes.
5. Click **Check Connection / Verify** ➔ Click the ribbon sync icon to run the initial sync.

### 2. Web Browser Access (Any Device)
1. Open `https://dev2.<tailnet>.ts.net:8083` in any browser while connected to Tailscale.
2. Log in with `obsidian` and your `FLATNOTES_PASSWORD`.
3. Search, view, and edit notes directly in your browser. Any change made in the browser automatically syncs to your desktop and mobile apps on their next sync!

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

---

## 📊 Beszel: Overall Server Health & Resource Dashboard

Beszel is a lightweight, real-time server monitoring hub and agent that tracks CPU, Memory, Disk, Network, temperature, and individual Docker container resource utilization.

### 1. Dashboard Access & Initial Admin Setup
1. Open the Beszel dashboard in any browser while connected to Tailscale:
   👉 **`https://dev2.<tailnet>.ts.net:8090`** (or `https://dev2.<tailnet>.ts.net:8090`)
2. On first launch, create your administrator email and password.

### 2. Adding `dev2` (Local Server Monitoring via Unix Domain Socket)
1. In the Beszel Hub UI, click **"Add System"**.
2. Set the parameters:
   - **Name**: `dev2`
   - **Host / IP**: `/beszel_socket/beszel.sock`
   - **Port**: `45876` *(ignored when using Unix socket)*
   - **Public Key**: Pre-matched with `data/dev2/beszel/data/id_ed25519.pub` and `BESZEL_KEY` in `hosts/dev2/.env`.
3. Click **"Add"**.
4. The dashboard immediately starts streaming live telemetry (CPU, RAM, Disk I/O, Network throughput, and per-container Docker metrics) with zero external port exposure!

### 3. Monitoring Other Nodes (e.g., `dev1` or Remote VPS)
To monitor additional servers on your tailnet:
1. In the Beszel UI, click **"Add System"** and enter the remote node name and Tailscale IP (or FQDN).
2. Copy the generated Docker Compose snippet containing the Hub's public key.
3. Deploy `henrygd/beszel-agent:latest` on the target machine pointing back to the Hub over Tailscale!

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
*Creates an atomic MariaDB hot dump + Firefly uploads + Obsidian Vault archive, restricts permissions (`0600`), prunes local backups older than 14 days, and syncs encrypted snapshots to Cloudflare R2 (`r2-crypt:`).*

### Automated Daily Backup Timer (Runs Daily at 03:00 UTC)
```bash
systemctl status homelab-backup.timer
systemctl list-timers homelab-backup.timer
```

### Disaster Recovery Restore
```bash
# From local backup
sudo bash /opt/homelab/scripts/restore_homelab.sh /opt/homelab/data/backups/homelab_backup_dev2_<timestamp>.tar.gz
```
