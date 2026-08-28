# Host: dev2 (Finance Stack)

## Services
- **Firefly III**: Self-hosted personal finance manager (`https://dev2.<tailnet>.ts.net`)
- **MariaDB**: Relational database backing Firefly III
- **Tailscale Serve**: HTTPS TLS termination on port 443

## Deployment
```bash
cd /opt/homelab/hosts/dev2
# Create .env from .env.example (if first time)
cp .env.example .env
# Start containers
docker compose up -d

# Start Tailscale Serve (HTTPS termination)
sudo tailscale serve --bg --https=443 http://127.0.0.1:8080
```
