---
title: "Network & Tailscale WireGuard Mesh"
type: architecture
category: networking
host: multi-host
status: active
tags:
  - homelab/architecture
  - category/networking
  - tailscale
  - wireguard
aliases:
  - Tailscale Mesh
  - MagicDNS Guide
  - Tailscale Network
created: 2026-08-28
last_updated: 2026-08-29
---

> 🧭 **Navigation**: [[00 - Homelab Hub|🏠 Homelab Hub]] ➔ [[00 - Architecture MOC|📐 Architecture]] ➔ **Network & Tailscale WireGuard Mesh**

# 🔐 Network & Tailscale WireGuard Mesh

Tailscale provides the encrypted mesh overlay network connecting homelab servers (`dev1`, `dev2`) and client devices (laptops, smartphones, tablets) into a zero-trust WireGuard network without open WAN firewall ports.

---

## 🌐 Network Specifications & Addressing

- **Protocol:** WireGuard (ChaCha20-Poly1305 authenticated encryption)
- **Overlay Subnet:** `100.64.0.0/10` (Carrier-Grade NAT)
- **MagicDNS Domain:** `<node>.<tailnet-id>.ts.net` (e.g., `dev1.<tailnet>.ts.net`)
- **DNS Resolver Integration:** Tailnet DNS queries are forwarded directly to AdGuard Home on `<dev1-tailscale-ip>:53`.

---

## ⚡ Ingress Mechanisms: Caddy vs. Tailscale Serve

To minimize overhead and respect host memory limits, the homelab utilizes two ingress patterns:

1. **`dev1` — Native Caddy Reverse Proxy**:
   - Caddy binds to `:80`, `:443`, `:8081`, and `:3001`.
   - Communicates with `/var/run/tailscale/tailscaled.sock` to obtain and renew trusted Let's Encrypt certificates automatically for `*.ts.net`.
2. **`dev2` — Tailscale Serve (`tailscale serve`)**:
   - Tailscale's built-in background proxy terminates TLS directly at the OS network daemon.
   - Maps external ports directly to container loopback ports:
     - `https://dev2.<tailnet>.ts.net` ➔ `127.0.0.1:8080` (Firefly Core)
     - `https://dev2.<tailnet>.ts.net:8443` ➔ `127.0.0.1:8081` (Firefly Importer)
     - `https://dev2.<tailnet>.ts.net:8082` ➔ `127.0.0.1:8082` (Obsidian WebDAV)
     - `https://dev2.<tailnet>.ts.net:8083` ➔ `127.0.0.1:8083` (Flatnotes Web)
     - `https://dev2.<tailnet>.ts.net:8090` ➔ `127.0.0.1:8090` (Beszel Hub)

---

## 🛠️ Operational CLI Commands

```bash
# Check node mesh status and active peers
tailscale status

# Check active Tailscale Serve TLS proxies on dev2
tailscale serve status

# Verify IP addressing
tailscale ip -4

# Re-authenticate node with SSH enabled
sudo tailscale up --ssh --accept-dns=true
```

---

## 🔗 Related Notes
- [[Ingress & Caddy Reverse Proxy|Caddy Reverse Proxy]]
- [[Service - Tailscale WireGuard Mesh|Tailscale Service Guide]]
- [[Security Model & Threat Isolation|Security Model & Threat Isolation]]
