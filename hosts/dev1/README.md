# Host: dev1 (Core Homelab Stack)

## Services
- **Vaultwarden**: Bitwarden-compatible password manager (`https://dev1.<tailnet>.ts.net`)
- **AdGuard Home**: Network-wide ad & tracker blocking DNS (`https://dev1.<tailnet>.ts.net:8081`)
- **Uptime Kuma**: Self-hosted uptime monitoring (`https://dev1.<tailnet>.ts.net:3001`)
- **Caddy**: Reverse proxy with automatic Tailscale TLS certificates
- **Beszel Agent**: Lightweight host resource & Docker container metric collector (Port 45876)

## Deployment
```bash
cd /opt/homelab/hosts/dev1
cp .env.example .env
# Set BESZEL_KEY from your dev2 Beszel Hub ("Add System" dialog)
docker compose up -d
```

### Adding `dev1` to Beszel Hub Dashboard (on `dev2`):
1. Open Beszel Hub on `dev2`: `https://dev2.<tailnet>.ts.net:8090`
2. Click **"Add System"**:
   - **Name**: `dev1`
   - **Host / IP**: `<dev1-tailscale-ip>` (or `dev1.<tailnet>.ts.net`)
   - **Port**: `45876`
   - **Public Key**: Copy the displayed public key into `BESZEL_KEY` in `hosts/dev1/.env`.
3. Click **"Add"**.

