# local-vps

One-command home server setup: installs **Coolify** or **EasyPanel** and exposes it publicly via a **Cloudflare Tunnel** — no router port forwarding needed.

## What it sets up

| Component | Details |
|-----------|---------|
| Panel | Coolify (port 8000) or EasyPanel (port 3000) |
| Public access | `https://cloud.yourdomain.com` via Cloudflare Tunnel |
| SSH via tunnel | `ssh user@ssh.yourdomain.com` through cloudflared |

## Requirements

- A Linux server (Ubuntu 20.04+, Debian 11+, or Raspbian)
- A domain managed in [Cloudflare DNS](https://dash.cloudflare.com)
- `curl` available on the server
- Root / sudo access

## Usage

### Option A — curl | bash

```bash
curl -fsSL https://raw.githubusercontent.com/jmbenck/local-vps/main/install.sh | sudo bash
```

### Option B — git clone

```bash
git clone https://github.com/jmbenck/local-vps
cd local-vps
sudo bash install.sh
```

## What happens during setup

1. Detects your OS and architecture
2. Asks which panel to install and your domain details
3. Installs Docker CE (if not present)
4. Installs the chosen panel
5. Installs `cloudflared` and walks you through Cloudflare authentication
6. Creates a named tunnel and DNS CNAME records automatically
7. Installs cloudflared as a systemd service

## SSH access from your local machine

After setup, on **your local machine**:

1. [Install cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/)

2. Add to `~/.ssh/config`:

```
Host ssh.yourdomain.com
  ProxyCommand cloudflared access ssh --hostname %h
```

3. Connect:

```bash
ssh root@ssh.yourdomain.com
```

The first connection opens a browser for Cloudflare authentication. Subsequent connections are transparent.

## Supported platforms

| OS | Versions | Architectures |
|----|----------|---------------|
| Ubuntu | 20.04, 22.04, 24.04 | amd64, arm64 |
| Debian | 11, 12 | amd64, arm64 |
| Raspbian | Bullseye, Bookworm | arm64, armhf |

## Idempotency

The script is safe to re-run. Each step checks whether it's already complete before proceeding. Existing Cloudflare tunnels are reused rather than duplicated.

## Security note

The official Coolify and EasyPanel installers are run via `curl | bash`. Review them at:
- Coolify: https://cdn.coollabs.io/coolify/install.sh
- EasyPanel: https://get.easypanel.io

For the same reason, Docker is installed via https://get.docker.com.
