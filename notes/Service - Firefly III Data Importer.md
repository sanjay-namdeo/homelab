# 📥 Service: Firefly III Data Importer (Automated Bank Importer)

**Firefly III Data Importer (FIDI)** is the official companion utility for Firefly III that converts and imports bank exports (CSV, CAMT.053, MT940, OFX, QIF, and Spectre API feeds) into transactions, creating accounts, tags, and categories automatically.

---

## 🏗️ Architecture & Deployment

- **Host Node:** `dev2`
- **Docker Image:** `fireflyiii/data-importer:latest`
- **Internal Port:** `127.0.0.1:8081`
- **Tailscale HTTPS Access:** `https://dev2.<tailnet>.ts.net:8443` (via Tailscale Serve)
- **Import Working Directory:** `/opt/homelab/data/dev2/firefly/import`
- **Communication:** Directly queries `firefly_app:8080` over the internal Docker network `firefly_net`.
- **Resource Constraints:** Max 256 MB RAM, 0.75 vCPU

```mermaid
graph LR
    User["👤 User (Web Browser)"] -->|HTTPS :8443| TS["⚡ Tailscale Serve (:8443)"]
    TS -->|HTTP :8080| FIDI["📥 Firefly Data Importer"]
    FIDI -->|JSON REST API (OAuth Token)| FFA["💰 Firefly III Core (:8080)"]
    FFA --> MDB[("🗄️ MariaDB Database")]
```

---

## ⚙️ Initial Authentication & Setup

### 1. Generating Personal Access Token (PAT)
1. Log into Firefly III Core: `https://dev2.<tailnet>.ts.net`
2. Navigate to **Profile** ➔ **OAuth** ➔ **Personal Access Tokens**.
3. Click **Create New Token**, enter `Data Importer Token`, and click **Create**.
4. Copy the long token string immediately (it will only be displayed once).

### 2. Accessing the Data Importer
1. Navigate to: **`https://dev2.<tailnet>.ts.net:8443`**
2. Paste the Personal Access Token in the authentication prompt.
3. Once authenticated, the Importer links with your Firefly III database.

*(Note: You can also set `FIREFLY_III_ACCESS_TOKEN=<token>` in `/opt/homelab/hosts/dev2/.env` so the importer remains persistently authenticated).*

---

## 📊 Bank Statement Import Workflow

### Step 1: Upload Statement File
- Support formats: `.csv`, `.xml` (CAMT.053), `.sta` (MT940), `.qif`, `.ofx`.
- Drag and drop your bank export file.

### Step 2: Column Mapping (For CSV Files)
Map your bank's CSV headers to Firefly fields:
- **Date:** Match date column and select date format (e.g. `YYYY-MM-DD` or `DD/MM/YYYY`).
- **Amount:** Select amount column.
- **Description / Narrative:** Match payee or description column.
- **Opposing Account / IBAN:** Match sender or receiver bank details.

### Step 3: Rule Application & Validation
- Check the box to apply Firefly III automation rules during import.
- Click **Validate Import** to preview mapped transactions and check for duplicate warnings.

### Step 4: Execute & Save Configuration
- Click **Start Import**. Transactions are written directly to Firefly III.
- **Save Configuration:** Click **Export Configuration (JSON)** to save your mapping profile. In future imports from the same bank, simply upload this JSON config to skip manual column mapping!

---

## 🤖 Automated Drop-Folder Imports

You can configure automatic imports without opening the web interface:

1. Place your exported bank CSV and saved mapping JSON in `/opt/homelab/data/dev2/firefly/import/`.
2. Trigger the auto-import endpoint using `AUTO_IMPORT_SECRET` configured in `.env`:
   ```bash
   curl -X POST "http://127.0.0.1:8081/autoupload?secret=<AUTO_IMPORT_SECRET>"
   ```
3. This command can be scheduled in crontab for scheduled headless imports.

---

## 💾 Backup & Data Protection

All saved import profiles, temporary conversion files, and auto-import queues are stored in `/opt/homelab/data/dev2/firefly/import`.

The automated backup script (`scripts/backup_homelab.sh --host dev2`) archives this directory completely.

---

## 🛠️ Operational & Diagnostic Commands

| Task | Command |
| :--- | :--- |
| **Check Importer Status** | `docker ps -f name=firefly_importer` |
| **View Live Logs** | `docker logs -f firefly_importer` |
| **Restart Importer** | `docker compose -f /opt/homelab/hosts/dev2/docker-compose.yml restart firefly_importer` |
| **Verify Import Permissions** | `ls -ld /opt/homelab/data/dev2/firefly/import` *(UID/GID 775)* |

---

## 🔗 Related Notes
- [[Service - Firefly III Core|Firefly III Core Setup & Guide]]
- [[Guide - Backup & Off-Site Sync|Homelab Backup & Snapshot Guide]]
- [[Guide - Disaster Recovery & Restore|Firefly Disaster Recovery]]
