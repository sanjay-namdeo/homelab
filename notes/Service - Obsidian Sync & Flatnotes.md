# 📝 Service: Obsidian Tri-Platform Sync & Flatnotes

This service stack provides a private, self-hosted note-taking infrastructure that connects official **Obsidian Desktop and Mobile apps** via WebDAV while simultaneously offering **Flatnotes** as a lightweight browser-based markdown editor.

---

## 🏗️ Architecture & Deployment

- **Host Node:** `dev2`
- **WebDAV Backend Image:** `bytemark/webdav:latest` (Port `127.0.0.1:8082`)
- **Flatnotes Web Editor Image:** `dullage/flatnotes:latest` (Port `127.0.0.1:8083`)
- **Tailscale Endpoints:**
  - WebDAV Sync: `https://dev2.<tailnet>.ts.net:8082/data/`
  - Flatnotes Web UI: `https://dev2.<tailnet>.ts.net:8083`
- **Shared Vault Storage:** `/opt/homelab/data/dev2/obsidian/vault` (Shared storage between WebDAV and Flatnotes)
- **Flatnotes Search Index:** `/opt/homelab/data/dev2/obsidian/flatnotes_data`
- **Permissions:** UID/GID `82:82` (`www-data`)
- **Resource Limits:** WebDAV Max 64 MB RAM (~5MB idle), Flatnotes Max 128 MB RAM (~50MB idle)

```mermaid
graph TD
    subgraph ClientDevices ["📱 Client Devices"]
        ObsidianPC["💻 Obsidian Desktop (Windows / Mac / Linux)"]
        ObsidianMobile["📱 Obsidian Mobile (iOS / Android)"]
        WebBrowser["🌐 Web Browser (Any Device)"]
    end

    subgraph TailscaleIngress ["🔐 Tailscale Serve TLS"]
        TS8082["Port 8082 (:8082)"]
        TS8083["Port 8083 (:8083)"]
    end

    subgraph BackendContainers ["🖥️ dev2 Docker Containers"]
        WebDAV["🔄 bytemark/webdav (:8082)"]
        Flatnotes["📝 dullage/flatnotes (:8083)"]
    end

    subgraph Storage ["💾 Shared Host Volume"]
        Vault[("📁 Obsidian Vault (/data/dev2/obsidian/vault)")]
        Index[("🔍 Search Index (/data/dev2/obsidian/flatnotes_data)")]
    end

    ObsidianPC <-->|Remotely Save (WebDAV HTTPS)| TS8082
    ObsidianMobile <-->|Remotely Save (WebDAV HTTPS)| TS8082
    WebBrowser <-->|Flatnotes Web GUI HTTPS| TS8083

    TS8082 --> WebDAV
    TS8083 --> Flatnotes

    WebDAV <--> Vault
    Flatnotes <--> Vault
    Flatnotes <--> Index
```

---

## 📱 Obsidian Desktop & Mobile Setup (Remotely Save Plugin)

Follow these steps on any Windows, macOS, Linux, iOS, or Android device:

### 1. Install Remotely Save Plugin
1. Open the **Obsidian** app.
2. Go to **Settings** (Gear icon) ➔ **Community plugins**.
3. Turn on Community Plugins and click **Browse**.
4. Search for **`Remotely Save`** (by *fyears* / *sboersma*) and click **Install**, then **Enable**.

### 2. Configure WebDAV Connection
1. In Obsidian Settings, open **Remotely Save** options:
   - **Sync Service:** Select `Webdav`.
   - **Server Address:**
     ```text
     https://dev2.<tailnet>.ts.net:8082/data/
     ```
     *(Make sure to include the trailing `/data/`).*
   - **Username:** `obsidian` (or configured `WEBDAV_USERNAME` in `hosts/dev2/.env`).
   - **Password:** Your configured `WEBDAV_PASSWORD`.
   - **Auth Type:** `Basic`
2. Scroll down and click **Check Connection / Verify**.
3. You should see: `Connect success! Server is available.`

### 3. Sync Automation
Under **Sync Schedule**:
- Enable **Run once on start up**.
- Enable **Run every 5 minutes** (or custom interval).
- Enable **Sync after note changes**.
4. Click the **Remotely Save sync ribbon icon** on the left toolbar to run the initial sync.

---

## 🌐 Flatnotes Web Markdown Editor

When you do not have Obsidian installed (e.g. on a work computer, tablet, or public browser):

1. Open **`https://dev2.<tailnet>.ts.net:8083`** while connected to Tailscale.
2. Log in with `obsidian` and your `FLATNOTES_PASSWORD`.
3. You can:
   - Search across all notes full-text instantly (powered by Whoosh search index).
   - View, edit, create, and organize Markdown notes.
   - Use `#tags`, wikilinks `[[Note Title]]`, and code blocks.
4. Any edit made in Flatnotes is saved immediately as raw `.md` files in the vault, which automatically syncs to your Obsidian desktop and mobile apps on their next sync cycle!

---

## 💾 Backup & Data Protection

All notes, markdown files, and attachments live directly in `/opt/homelab/data/dev2/obsidian/vault`.

The automated backup script (`scripts/backup_homelab.sh --host dev2`) archives:
- `/opt/homelab/data/dev2/obsidian/vault/` (all `.md` notes, image attachments, canvas files)
- `/opt/homelab/data/dev2/obsidian/flatnotes_data/` (search indices and configuration)

---

## 🛠️ Operational & Maintenance Commands

| Task | Command |
| :--- | :--- |
| **Check Containers Status** | `docker ps -f name=obsidian_` |
| **View WebDAV Logs** | `docker logs -f obsidian_webdav` |
| **View Flatnotes Logs** | `docker logs -f obsidian_web` |
| **Fix Permissions** | `sudo chown -R 82:82 /opt/homelab/data/dev2/obsidian && sudo chmod -R 775 /opt/homelab/data/dev2/obsidian` |
| **Rebuild Search Index** | `docker restart obsidian_web` |

---

## 🔗 Related Notes
- [[00 - Homelab Overview & Architecture|Homelab Overview]]
- [[Service - Tailscale WireGuard Mesh|Tailscale WireGuard Mesh Guide]]
- [[Guide - Backup & Off-Site Sync|Homelab Backup & Snapshot Guide]]
- [[Guide - Disaster Recovery & Restore|Obsidian Disaster Recovery]]
