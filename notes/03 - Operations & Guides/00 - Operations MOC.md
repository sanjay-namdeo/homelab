---
title: "Operations & Guides Map of Content"
type: moc
category: operations
host: multi-host
status: active
tags:
  - homelab
  - homelab/moc
  - operations
  - guides
aliases:
  - Operations MOC
  - Guides Directory
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ **Operations & Guides**

# 🛠️ Operations & Guides Map of Content

This directory contains standard operating procedures (SOPs), routine maintenance checklists, notification integrations, and multi-device client setup guides.

---

## 📑 Operational Guides

- [[Guide - Operations, Maintenance & Troubleshooting|Operations, Maintenance & Troubleshooting Guide]]
  *Routine maintenance cadences (daily, weekly, monthly), health diagnostics, zero-downtime updates, and error triage.*
- [[Guide - Notifications & Alerting (Telegram, Pushover, Email)|Multi-Tier Notifications & Alerting Guide]]
  *Comparison of notification tools (Telegram, Pushover, ntfy.sh, Email), BotFather setup, and Uptime Kuma alerting configuration.*
- [[Guide - Obsidian Multi-Device Setup & Remotely Save|Obsidian Multi-Device Setup & Remotely Save Guide]]
  *Step-by-step installation on Linux, macOS, Windows, iOS, and Android; WebDAV synchronization with Remotely Save; Flatnotes web access.*
- [[Guide - Beszel Multi-Node Monitoring Setup|Beszel Multi-Node Monitoring Setup Guide]]
  *Step-by-step instructions for adding local (`dev2` Unix socket) and remote (`dev1` TCP `45876`) nodes into Beszel Hub.*

---

## 📅 Routine Maintenance Schedule

| Frequency | Action | Command / Procedure |
| :--- | :--- | :--- |
| **Daily** | Automated Point-in-Time Backup | Managed via cron / systemd (`scripts/backup_homelab.sh`) |
| **Weekly** | Health Diagnostic Check | `sudo bash /opt/homelab/scripts/healthcheck.sh` |
| **Monthly** | Host Security Updates | `sudo apt update && sudo apt upgrade -y` |
| **Monthly** | Docker Image Pulls | Pull latest stable container images and verify health |
| **Quarterly** | Disaster Recovery Drill | Execute dry-run restoration (`scripts/restore_homelab.sh`) |

---

## 🔗 Related Sections
- [[00 - Architecture MOC|📐 01 - Architecture & Infrastructure]]
- [[00 - Services MOC|📦 02 - Core Services]]
- [[00 - Disaster Recovery MOC|🚑 04 - Disaster Recovery & Backups]]
