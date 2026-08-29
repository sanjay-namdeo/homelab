---
title: "Security Model & Threat Isolation"
type: architecture
category: security
host: multi-host
status: active
tags:
  - homelab/architecture
  - category/security
  - security
  - hardening
aliases:
  - Security Model
  - Threat Model
  - Hardening Guide
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Architecture MOC|📐 Architecture]] ➔ **Security Model & Threat Isolation**

# 🔒 Security Model & Threat Isolation

This document outlines the defence-in-depth security architecture governing the homelab, container isolation, access controls, and data protection policies.

---

## 🛡️ Core Security Principles

### 1. Zero WAN Port Forwarding (No Public Surface)
- No public ports (80, 443, 53, 22, etc.) are open on external cloud firewalls or routers.
- All ingress traffic is strictly constrained to the authenticated WireGuard overlay mesh (`tailscale0`).

### 2. Strict Local Loopback Binding (`127.0.0.1`)
- Application container ports bind exclusively to `127.0.0.1` or internal Docker bridge networks (`firefly_net`).
- Public and local LAN interfaces cannot connect directly to application HTTP ports.

### 3. File System & Secrets Permission Lockdown
- Environment secrets files (`.env`) are strictly locked to `0600` (`-rw-------`, owned by `root`).
- Database storage directories are restricted to `0700` or minimal service user IDs (`999:999` for MariaDB, `82:82` for Flatnotes).
- Daily backup archives are generated with `0600` permissions.

### 4. Zero-Knowledge Off-Site Replication
- Offsite backups replicated to Cloudflare R2 are encrypted client-side using `rclone` with AES-256-GCM authenticated encryption (`r2-crypt:`).

---

## 🔍 Security Audit Checklist

Run the automated diagnostic tool to verify all isolation guarantees:
```bash
sudo bash /opt/homelab/scripts/healthcheck.sh
```

| Verification Item | Expected State | Validation Method |
| :--- | :--- | :--- |
| **External Port 8080/8081/8082** | Connection Refused / Filtered | `nc -z -w 1 <LAN_IP> 8080` |
| **Secrets Permissions** | `0600` (root:root) | `stat -c "%a" hosts/dev2/.env` |
| **Vaultwarden DB Permissions**| `0700` (root:root) | `stat -c "%a" data/vaultwarden` |
| **Rclone Offsite Secret** | `0600` (root:root) | `stat -c "%a" data/rclone/rclone.conf` |

---

## 🔗 Related Notes
- [[Homelab Architecture & Topology|Homelab Architecture & Topology]]
- [[Guide - Backup & Off-Site Sync (Cloudflare R2)|Backup & Sync Guide]]
- [[Disaster Recovery Runbook - dev1|Disaster Recovery Runbook: dev1]]
- [[Disaster Recovery Runbook - dev2|Disaster Recovery Runbook: dev2]]
