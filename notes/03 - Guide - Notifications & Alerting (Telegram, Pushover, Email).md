---
title: "Guide: Notifications & Alerting (Telegram, Pushover, Email)"
type: guide
category: monitoring
host: multi-host
status: active
tags:
  - homelab/guide
  - category/monitoring
  - telegram
  - pushover
  - alerts
aliases:
  - Alerting Guide
  - Telegram Alerts
  - Notification Setup
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Operations MOC|🛠️ Operations]] ➔ **Notifications & Alerting**

# 📢 Guide: Notifications & Alerting (Telegram, Pushover, Email)

For real-time homelab alerting, email is not suitable as a primary channel because mobile clients throttle background sync and emails cannot bypass Do Not Disturb (DND) focus modes. This guide establishes our multi-tier notification strategy.

---

## 🏆 Notification Channels Compared

| Channel | Latency | Cost | DND / Sleep Bypass | Best For |
| :--- | :--- | :--- | :--- | :--- |
| 🥇 **Telegram** | Instant (~1s) | Free | ⚠️ No (unless app whitelisted) | **Primary instant alerting channel** |
| 🥈 **Pushover** | Sub-second (<1s)| $5 one-time | ✅ Yes (Emergency Priority rings siren)| **Mission-critical wakeup alerts** |
| 🥉 **ntfy.sh** | Sub-second (<1s)| Free / Self-host | ✅ Yes (Urgent Priority) | **Open-source & self-hostable push** |
| ✉️ **Email (Brevo)**| 5–30s+ delay | Free tier | ❌ No | **Secondary audit trail & reports** |

---

## 💡 Recommended Two-Tier Notification Architecture

1. **Tier 1: Instant Real-Time Alerting (Telegram / Pushover)**
   - Delivers instant notifications the exact second a service, container, or server stops responding.
2. **Tier 2: Permanent Audit Trail (Email via Brevo SMTP)**
   - Retains structured HTML status emails and SSL certificate renewal records.

---

## 🚀 Setting Up Telegram Instant Alerts in Uptime Kuma

### Step 1: Create a Telegram Bot
1. Open Telegram and search for [@BotFather](https://t.me/BotFather).
2. Send `/newbot`.
3. Choose a friendly name (e.g. `Homelab Alert Bot`) and username ending in `bot` (e.g. `sanjay_homelab_alert_bot`).
4. Copy the generated **HTTP API Bot Token** (e.g. `123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ`).

### Step 2: Retrieve Your Telegram Chat ID
1. Search for [@userinfobot](https://t.me/userinfobot) on Telegram and press **Start**.
2. Note your numeric **Id** (e.g. `987654321`).
3. Search for your new bot by its username and click **Start** (to grant permission for the bot to message you).

### Step 3: Configure Uptime Kuma
1. Open Uptime Kuma: `https://dev1.<tailnet>.ts.net:3001`
2. Navigate to **Settings ➔ Notifications ➔ Setup Notification**.
3. Fill in:
   - **Notification Type:** `Telegram`
   - **Friendly Name:** `Telegram Instant Alerts`
   - **Bot Token:** `<Your-Bot-Token>`
   - **Chat ID:** `<Your-Chat-ID>`
   - **Default enabled:** Checked ✅
4. Click **Test** (you will receive a test ping within 1 second).
5. Click **Save**.

---

## 📱 Emergency Wakeup Alerts with Pushover

If you want critical alerts to wake you up when your phone is in Sleep or Do Not Disturb mode:
1. Register an account at [Pushover.net](https://pushover.net).
2. Create an Application Token in Pushover.
3. In Uptime Kuma, select **Pushover** and set Priority to `2 (Emergency)` with 60-second retry intervals.

---

## 🔗 Related Notes
- [[Service - Uptime Kuma|Uptime Kuma Service Guide]]
- [[Service - Beszel Server Monitoring|Beszel Server Monitoring]]
- [[Guide - Operations, Maintenance & Troubleshooting|Operations & Troubleshooting Guide]]
