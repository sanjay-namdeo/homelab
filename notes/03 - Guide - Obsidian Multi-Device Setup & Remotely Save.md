---
title: "Guide: Obsidian Multi-Device Setup & Remotely Save"
type: guide
category: knowledge
host: client
status: active
tags:
  - homelab/guide
  - category/knowledge
  - obsidian
  - remotely-save
  - webdav
aliases:
  - Obsidian Setup Guide
  - Remotely Save Guide
  - Obsidian Mobile Setup
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Operations MOC|🛠️ Operations]] ➔ **Obsidian Multi-Device Setup**

# 📝 Guide: Obsidian Multi-Device Setup & Remotely Save

This guide walks through configuring **Obsidian Desktop** (Linux, macOS, Windows) and **Obsidian Mobile** (iOS, Android) to synchronize private markdown notes with your self-hosted WebDAV backend over Tailscale.

---

## 💻 Step 1: Install Obsidian on Your Laptop / PC

Choose the installation method matching your OS:

### Linux (Ubuntu / Debian)
- **Via Snap:** `sudo snap install obsidian --classic`
- **Via Flatpak:** `flatpak install flathub md.obsidian.Obsidian`
- **Via .deb:** Download from [obsidian.md/download](https://obsidian.md/download) and run `sudo apt install ./obsidian_*.deb`

### macOS
- **Via Homebrew:** `brew install --cask obsidian`
- **Manual:** Download DMG installer from [obsidian.md/download](https://obsidian.md/download).

### Windows
- **Via Winget:** `winget install Obsidian.Obsidian`
- **Manual:** Download installer from [obsidian.md/download](https://obsidian.md/download).

---

## 📱 Step 2: Ensure Tailscale is Connected on Your Device

Because your WebDAV sync server is hosted securely on your private Tailscale network, ensure Tailscale is active on your device:
```bash
tailscale status
# Verify that dev2 is visible in your peer list
```

---

## ⚙️ Step 3: Configure WebDAV Sync via "Remotely Save"

1. **Open Obsidian & Create/Open a Vault**:
   - Create a new vault named `Homelab` or open your local notes folder.
2. **Install the "Remotely Save" Community Plugin**:
   - Open **Settings (⚙️)** ➔ **Community plugins** ➔ Enable community plugins.
   - Click **Browse**, search for `Remotely Save`, click **Install**, then **Enable**.
3. **Configure the WebDAV Connection**:
   - In Settings ➔ **Remotely Save**:
     - **Sync Service:** `Webdav`
     - **Server Address:** `https://dev2.<tailnet>.ts.net:8082/data/`
     - **Username:** `obsidian` (or configured `WEBDAV_USERNAME` in `hosts/dev2/.env`)
     - **Password:** `<WEBDAV_PASSWORD>`
     - **Auth Type:** `Basic`
4. **Set Up Automated Sync Cadence**:
   - **Auto run after starting Obsidian:** Enable (5s delay).
   - **Auto run every:** 5 minutes.
   - **Sync on save / file change:** Enable.
5. **Test & Trigger Initial Sync**:
   - Click **Check Connection** (verify green success alert).
   - Click the Sync icon (two circular arrows) in the left sidebar ribbon.

---

## 🌐 Step 4: Browser Access via Flatnotes

When on a device without Obsidian installed, you can read, search, and edit notes in any web browser:
- **URL:** `https://dev2.<tailnet>.ts.net:8083`
- **Username:** `obsidian`
- **Password:** `<FLATNOTES_PASSWORD>`

---

## 🔗 Related Notes
- [[Service - Obsidian Sync & Flatnotes|Obsidian Service Architecture]]
- [[Disaster Recovery Runbook - dev2|dev2 Disaster Recovery Runbook]]
