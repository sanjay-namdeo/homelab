# 🔑 Service: Vaultwarden (Bitwarden Server)

**Vaultwarden** is an alternative, lightweight implementation of the Bitwarden server API written in Rust. It provides full compatibility with all official Bitwarden applications and browser extensions while consuming only ~15–25 MB of RAM.

---

## 🏗️ Architecture & Deployment

- **Host Node:** `dev1`
- **Docker Image:** `vaultwarden/server:alpine`
- **Local Listening Port:** `127.0.0.1:8080`
- **Ingress / Reverse Proxy:** Caddy (`https://dev1.<tailnet>.ts.net`)
- **Database:** SQLite with Write-Ahead Logging (`db.sqlite3`, `db.sqlite3-wal`)
- **Data Directory:** `/opt/homelab/data/vaultwarden`
- **Resource Constraints:** Max 128 MB RAM, 0.50 vCPU

```mermaid
graph LR
    Client["📱 Bitwarden App / Extension"] -->|Encrypted HTTPS| Caddy["⚡ Caddy Reverse Proxy (:443)"]
    Caddy -->|HTTP :8080| VW["🔑 Vaultwarden Server"]
    VW -->|ACID Transactions (WAL Mode)| SQLite[("🗄️ SQLite DB (/data/vaultwarden)")]
```

---

## ⚙️ Initial Setup & Registration

1. **Accessing the Web Vault:**
   - Connect to Tailscale on your client device.
   - Navigate to: **`https://dev1.<tailnet>.ts.net`** (or your server's Tailscale domain).
2. **Create Primary Account:**
   - Click **Create account**.
   - Enter your email address and generate a strong, memorable Master Password.
   - Verify your vault opens successfully.
3. **Lock Down Public Registrations:**
   Once your admin and family/personal accounts are created, disable public signups to prevent unauthorized users on your tailnet from creating vaults:
   - Edit `/opt/homelab/.env` on `dev1`:
     ```ini
     SIGNUPS_ALLOWED=false
     ```
   - Restart the Vaultwarden container:
     ```bash
     cd /opt/homelab && docker compose up -d vaultwarden
     ```

---

## 📱 Connecting Bitwarden Client Applications

You can connect official Bitwarden apps on Windows, macOS, Linux, iOS, Android, and all major browser extensions (Chrome, Firefox, Safari, Brave, Edge).

### Connection Steps:
1. Open the Bitwarden App or Browser Extension.
2. On the initial login screen, click the **Gear Icon (Settings)** at the top left.
3. Under **Server URL**, enter:
   ```text
   https://dev1.<tailnet>.ts.net
   ```
   *(Note: Do not enter a trailing slash or port number, as Caddy serves standard port 443).*
4. Click **Save**.
5. Enter your email and master password to log in.
6. Enable **Biometric Unlock** (Touch ID, Face ID, Windows Hello) and **PIN unlock** in client settings.

---

## 🔒 Security Hardening & Admin Portal

### 1. Argon2id Password Hashing
Vaultwarden uses Argon2id key derivation by default, providing superior resistance against GPU brute-force attacks compared to standard PBKDF2.

### 2. Admin Token (Optional)
To access the `/admin` diagnostic portal:
1. Generate an Argon2 admin hash:
   ```bash
   docker run --rm -it vaultwarden/server:alpine /vaultwarden hash
   ```
2. Add the generated hash to `/opt/homelab/.env`:
   ```ini
   ADMIN_TOKEN='$argon2id$v=19$m=65536,t=3,p=4$...'
   ```
3. Access the admin dashboard at: `https://dev1.<tailnet>.ts.net/admin`

### 3. Real-Time WebSocket Push Notifications
WebSocket synchronization is natively enabled in Vaultwarden and reverse-proxied through Caddy, ensuring instantaneous vault sync when items are added or modified across multiple devices.

---

## 💾 Backup & Data Protection

Vaultwarden's SQLite database utilizes WAL mode. Taking raw file copies of `db.sqlite3` while running can result in corrupted snapshots.

Our automated backup script utilizes Python's native `sqlite3.backup()` API to lock and create atomic, 100% consistent live snapshots:

```bash
# Run manual backup
sudo bash /opt/homelab/scripts/backup_homelab.sh --host dev1
```

The backup captures:
- `db.sqlite3` (point-in-time consistent snapshot)
- `rsa_key.pem`, `rsa_key.pub` (asymmetric cryptographic keys)
- `attachments/` & `sends/` directories
- `config.json`

---

## 🛠️ Troubleshooting & Operational Commands

| Task | Command |
| :--- | :--- |
| **Check Container Status** | `docker ps -f name=vaultwarden` |
| **View Live Logs** | `docker logs -f vaultwarden` |
| **Restart Service** | `cd /opt/homelab && docker compose restart vaultwarden` |
| **Verify SQLite Integrity** | `sqlite3 /opt/homelab/data/vaultwarden/db.sqlite3 "PRAGMA integrity_check;"` |
| **Upgrade Vaultwarden** | `sudo bash /opt/homelab/scripts/update_vaultwarden.sh` |

---

## 🔗 Related Notes
- [[Service - Caddy Reverse Proxy|Caddy Reverse Proxy Configuration]]
- [[Guide - Backup & Off-Site Sync|Homelab Backup & Snapshot Guide]]
- [[Guide - Disaster Recovery & Restore|Vaultwarden Disaster Recovery]]
