# GEMINI.md — Agent Context for Gemini

This file gives Gemini AI the context it needs to assist effectively with this repository.

---

## Project Overview

**Personal Cloud & Multi-Host Homelab** — a lightweight, production-grade, self-hosted infrastructure
organised as a multi-host monorepo. It targets resource-constrained servers such as 1 GB RAM cloud VMs,
Raspberry Pis, and home servers.

Core design principles:
- **Zero public port exposure** — all traffic is routed over Tailscale WireGuard mesh (`*.ts.net`).
- **Zero domain / free SSL** — Tailscale MagicDNS + automatic Let's Encrypt certificates, no purchased domain.
- **RAM-tuned** — strict Docker memory limits prevent OOM crashes on 1 GB instances.
- **Disaster recovery first** — automated off-site encrypted backups to Cloudflare R2 with < 5-min RTO.

---

## Host Architecture

| Host | Role | Key Services |
|------|------|--------------|
| `dev1` | Core Infrastructure & WebDAV | Vaultwarden (:8080), AdGuard Home (:53/:8081), Obsidian WebDAV (:8082), Caddy, Beszel Agent |
| `dev2` | Knowledge Hub & Monitoring | Flatnotes (:8083), Gatus (:8085), Beszel Hub (:8090) — TLS via `tailscale serve` |

Network: All services communicate over a shared Docker bridge network (`homelab_net`), exposed only on
`127.0.0.1` or the private Tailscale interface (`100.64.0.0/10`).

---

## Repository Layout

```
homelab/
├── hosts/
│   ├── dev1/              # Core Privacy & Cloud Stack
│   │   ├── docker-compose.yml
│   │   ├── Caddyfile
│   │   └── .env.example
│   └── dev2/              # Knowledge & Monitoring Stack
│       ├── docker-compose.yml
│       ├── gatus/config.yaml
│       └── .env.example
├── notes/                 # Obsidian-compatible knowledge vault (Markdown)
├── scripts/               # Operational automation scripts
├── data/                  # Runtime data (gitignored: vaultwarden, adguard, caddy, obsidian, backups)
├── Caddyfile              # dev1 root Caddy config (backward compat)
├── docker-compose.yml     # dev1 root compose (backward compat)
├── .env / .env.example    # Environment variables — NEVER commit .env
├── GEMINI.md              # This file
├── CLAUDE.md              # Claude agent context
├── README.md              # Human-facing overview
└── SETUP_AND_REPLICATION_GUIDE.md
```

---

## Key Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` / `hosts/dev1/docker-compose.yml` | dev1 service definitions |
| `hosts/dev2/docker-compose.yml` | dev2 service definitions |
| `Caddyfile` / `hosts/dev1/Caddyfile` | Caddy reverse proxy & TLS config |
| `hosts/dev2/gatus/config.yaml` | Gatus health-check endpoint definitions |
| `.env.example` | Template for required environment variables |
| `scripts/deploy_stack.sh` | Auto-detects host, sets up Docker/Tailscale, starts stack |
| `scripts/backup_homelab.sh` | Hot SQLite snapshots + encrypted Cloudflare R2 upload |
| `scripts/restore_homelab.sh` | Point-in-time disaster recovery from backup archive |
| `scripts/healthcheck.sh` | 5-tier diagnostic: Tailscale, Docker, HTTPS, DNS, system resources |
| `scripts/update_vaultwarden.sh` | Zero-downtime Vaultwarden image update (~1–2 s downtime) |
| `scripts/rollback.sh` | Full teardown — stops containers, purges Docker & Tailscale, wipes /opt/homelab |

---

## Environment Variables

All secrets live in `.env` files (gitignored). Key variables:

```dotenv
TZ=Asia/Kolkata
DEV1_TAILSCALE_FQDN=dev1.<tailnet>.ts.net
DEV1_TAILSCALE_IP=100.x.x.x
DEV2_TAILSCALE_FQDN=dev2.<tailnet>.ts.net
DEV2_TAILSCALE_IP=100.x.x.x

# Vaultwarden SMTP
SMTP_HOST=...
SMTP_USERNAME=...
SMTP_PASSWORD=...
SMTP_FROM=...

# WebDAV
WEBDAV_USERNAME=obsidian
WEBDAV_PASSWORD=...

# Beszel
BESZEL_KEY=...

# Cloudflare R2 (backup)
R2_BUCKET=...
RCLONE_CONFIG_PATH=...
```

Never edit `.env` files directly when asked — update `.env.example` and instruct the user to replicate.

---

## Operational Conventions

1. **Deployment**: Use `sudo bash scripts/deploy_stack.sh [dev2]`. It auto-detects the host.
2. **Backups**: Triggered via systemd timer `homelab-backup.timer` at 03:00 UTC daily.
   Manual: `sudo bash scripts/backup_homelab.sh`.
3. **Secrets**: All `.env` files are gitignored. Never suggest committing secrets.
4. **Memory limits**: Every container has explicit `deploy.resources.limits.memory` — do not remove these.
5. **Network binding**: Services must bind to `127.0.0.1` or the Tailscale IP — never `0.0.0.0` on public ports.
6. **Image tags**: Prefer `alpine`-based images for minimal footprint. Pin tags in production changes.
7. **Documentation**: Infrastructure notes live in `notes/` (Markdown, Obsidian-compatible).

---

## Common Tasks for Gemini

- **Add a new service**: Create a new service block in the appropriate `hosts/<host>/docker-compose.yml`,
  add memory/CPU limits, bind only to `127.0.0.1`, and add Caddy or `tailscale serve` routing.
- **Update a script**: All scripts in `scripts/` use `bash` with `set -euo pipefail`. Preserve error handling.
- **Edit Gatus config**: Endpoints are defined in `hosts/dev2/gatus/config.yaml` — use YAML anchors for DRY config.
- **Disaster recovery drill**: Run `sudo bash scripts/test_disaster_recovery.sh`.
- **Health check**: Run `sudo bash scripts/healthcheck.sh` for a full 5-tier diagnostic report.

---

## Notes / Knowledge Base

The `notes/` directory is an Obsidian vault with the following sections:

| Prefix | Content |
|--------|---------|
| `00 -` | Homelab Hub — master index & live service directory |
| `01 -` | Architecture — topology, specs, network, security |
| `02 -` | Services — per-service detail (Vaultwarden, AdGuard, etc.) |
| `03 -` | Operations — maintenance, troubleshooting, email alerting |
| `04 -` | Disaster Recovery — backup strategy, restore runbooks, DR drills |
| `Template -` | Reusable note templates |

Notes are synced to a live Flatnotes web editor on dev2 via `scripts/sync_notes_to_vault.sh` and
bidirectionally to Obsidian Desktop/Mobile via WebDAV at `https://dev1.<tailnet>.ts.net:8082/data/`.
