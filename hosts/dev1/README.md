# Host: dev1 (Core Homelab Stack)

## Services
- **Vaultwarden**: Bitwarden-compatible password manager (`https://dev1.<tailnet>.ts.net`)
- **AdGuard Home**: Network-wide ad & tracker blocking DNS
- **Uptime Kuma**: Self-hosted uptime monitoring
- **Caddy**: Reverse proxy with automatic Tailscale TLS certificates

## Deployment
```bash
cd /opt/homelab/hosts/dev1
docker compose up -d
```
