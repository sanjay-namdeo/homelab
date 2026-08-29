# 📈 Service: Beszel (Server Health & Resource Monitoring)

**Beszel** is an ultra-lightweight, real-time server resource monitoring hub and agent that tracks CPU, Memory, Swap, Disk I/O, Network throughput, host temperatures, and per-container Docker CPU/RAM utilization.

---

## 🏗️ Architecture & Deployment

Beszel operates on a Hub-and-Agent architecture:
- **Beszel Hub (`beszel`):** Deployed on `dev2` (Port `127.0.0.1:8090`, proxied via Tailscale Serve to `https://dev2.<tailnet>.ts.net:8090`). Stores time-series metrics in an embedded PocketBase database.
- **Beszel Agent (`beszel_agent` on `dev2`):** Communicates with the local Hub directly via a shared Unix Domain Socket (`/beszel_socket/beszel.sock`), eliminating host port exposure.
- **Beszel Agent (`beszel_agent` on `dev1`):** Listens on port `45876` bound to host network mode, allowing the Hub on `dev2` to query telemetry securely over the Tailscale WireGuard mesh.
- **Resource Footprint:** Hub uses ~15 MB RAM; Agent uses ~8 MB RAM.

```mermaid
graph TD
    User["👤 Browser (Admin)"] -->|HTTPS :8090| TS["⚡ Tailscale Serve (:8090)"]
    TS -->|HTTP :8090| Hub["📊 Beszel Hub (dev2)"]

    subgraph NodeDev2 ["🖥️ dev2 (Local Node)"]
        Hub <-->|UNIX Socket IPC (/beszel_socket/beszel.sock)| Agent2["📈 Beszel Agent (dev2)"]
    end

    subgraph NodeDev1 ["🖥️ dev1 (Remote Node)"]
        Hub <-->|Tailscale Mesh (Port 45876)| Agent1["📈 Beszel Agent (dev1)"]
    end
```

---

## ⚙️ Initial Admin Setup & Hub Access

1. Open **`https://dev2.<tailnet>.ts.net:8090`** on your browser (connected to Tailscale).
2. On first visit, register your administrative email and password.

---

## 🖥️ Adding Monitored Nodes in Beszel

### 1. Adding `dev2` (Local Node via Unix Domain Socket)
1. In the Beszel UI, click **"Add System"**.
2. Enter the configuration:
   - **Name:** `dev2`
   - **Host / IP:** `/beszel_socket/beszel.sock`
   - **Port:** `45876` *(ignored when socket path is provided)*
   - **Public Key:** Match the public key shown on the screen or configured in `hosts/dev2/.env` (`BESZEL_KEY`).
3. Click **"Add"**. Telemetry streaming begins immediately with zero external network overhead!

### 2. Adding `dev1` (Remote Monitoring over Tailscale)
1. In the Beszel UI, click **"Add System"**.
2. Enter the configuration:
   - **Name:** `dev1`
   - **Host / IP:** `<dev1-tailscale-ip>` (or `dev1.<tailnet>.ts.net`)
   - **Port:** `45876`
   - **Public Key:** Copy the Hub's Ed25519 Public Key.
3. Ensure `beszel_agent` is running on `dev1` with `KEY="<Hub Public Key>"`:
   ```bash
   # On dev1:
   docker run -d \
     --name beszel_agent \
     --restart unless-stopped \
     --net=host \
     -v /var/run/docker.sock:/var/run/docker.sock:ro \
     -e PORT=45876 \
     -e KEY="<Hub Public Key>" \
     henrygd/beszel-agent:latest
   ```
4. Click **"Add"** in the UI. Live CPU, RAM, Disk, and Docker stats for `dev1` will appear on your central dashboard.

---

## 📊 Telemetry Metrics Tracked

- **System Metrics:**
  - Real-time CPU usage percentage & load average
  - RAM usage, active cache, and Swap memory
  - Disk space, read/write I/O throughput
  - Network interface ingress and egress throughput
  - CPU temperature sensors
- **Docker Container Analytics:**
  - Individual CPU usage per container
  - Individual Memory consumption per container
  - Container restart count and uptime status

---

## 💾 Backup & Data Protection

Beszel stores historical metrics and node credentials in PocketBase at `/opt/homelab/data/dev2/beszel/data`.

The automated backup script (`scripts/backup_homelab.sh --host dev2`) archives:
- `/opt/homelab/data/dev2/beszel/data/` (time-series database & SSH keys)

---

## 🛠️ Operational Commands

| Task | Command |
| :--- | :--- |
| **Check Hub Status** | `docker ps -f name=beszel` |
| **Check Agent Status (dev1/dev2)** | `docker ps -f name=beszel_agent` |
| **View Hub Logs** | `docker logs -f beszel` |
| **View Agent Logs** | `docker logs -f beszel_agent` |
| **Check Listening Port on dev1** | `ss -tulpn \| grep 45876` |

---

## 🔗 Related Notes
- [[Service - Uptime Kuma|Uptime Kuma Uptime & Alert Monitor]]
- [[Service - Tailscale WireGuard Mesh|Tailscale WireGuard Mesh Guide]]
- [[Guide - Backup & Off-Site Sync|Homelab Backup & Snapshot Guide]]
