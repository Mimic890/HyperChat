# 🔥 HyperChat

**Self-hosted Matrix/Synapse stack — private messenger with optional bridges, VoIP, and S3 storage, deployed in minutes.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What's included

| Service | Image | Notes |
|---------|-------|-------|
| **Synapse** | `matrixdotorg/synapse:latest` | Matrix homeserver |
| **PostgreSQL 16** | `postgres:16-alpine` | Primary database |
| **Redis 7** | `redis:7-alpine` | Cache & worker coordination |
| **Element Web** | `vectorim/element-web:latest` | Web client *(optional)* |
| **Cinny** | `ghcr.io/cinnyapp/cinny:latest` | Alt web client *(optional)* |
| **Synapse Admin** | `awesometechnologies/synapse-admin:latest` | Admin panel — always on `127.0.0.1` |
| **Coturn** | `coturn/coturn:latest` | TURN/STUN for 1-to-1 calls *(optional)* |
| **LiveKit** | `livekit/livekit-server:latest` | Group video calls *(optional)* |
| **Garage** | `dxflrs/garage:v1.0.0` | Local S3-compatible storage *(optional)* |
| **mautrix-telegram** | `dock.mau.dev/mautrix/telegram:latest` | Telegram bridge *(optional)* |
| **mautrix-whatsapp** | `dock.mau.dev/mautrix/whatsapp:latest` | WhatsApp bridge *(optional)* |
| **mautrix-discord** | `dock.mau.dev/mautrix/discord:latest` | Discord bridge *(optional)* |
| **mautrix-signal** | `dock.mau.dev/mautrix/signal:latest` | Signal bridge *(optional)* |
| **nginx** | `nginx:alpine` | Sticker picker host *(optional)* |

Optional services are enabled in `.env` and activated automatically by `make build`.

---

## Deploy modes

Set `DEPLOY_MODE` in `.env` before running `make build`:

| Mode | Value | Description |
|------|-------|-------------|
| Local | `1` | Ports bound to `127.0.0.1`. For testing on your own machine. |
| Local + Traefik | `2` | Traefik inside Docker, HTTP only, no SSL. For LAN or behind your own SSL terminator. |
| Server | `3` | Your own nginx/Caddy on the host handles SSL. Services bound to `127.0.0.1`. |
| Server + Traefik | `4` | Traefik inside Docker handles SSL via Let's Encrypt. Best when no existing web server. |

---

## Quick start (server with Caddy)

### Prerequisites

- Docker Engine 24+ with Docker Compose v2
- GNU Make (`apt install make`)
- [Caddy](https://caddyserver.com) installed as a system service
- A domain with DNS pointing to your server

### 1. Clone

```bash
git clone https://github.com/Mimic890/HyperChat.git
cd HyperChat
```

### 2. Configure

```bash
cp .env.example .env
nano .env
```

Minimum required settings:

```ini
DEPLOY_MODE=3        # server with your own reverse proxy (Caddy)
DOMAIN=hyperchat.ru  # your domain — no https:// or trailing slash
SERVER_NAME=chat     # short label for the Matrix server name
```

By default these subdomains are used:

| Setting | Default | Result |
|---------|---------|--------|
| `SUBDOMAIN_MATRIX=matrix` | `matrix` | `matrix.hyperchat.ru` — Synapse API |
| `SUBDOMAIN_ELEMENT=` | *(empty)* | `hyperchat.ru` — Element Web (root domain) |
| `SUBDOMAIN_CINNY=cinny` | `cinny` | `cinny.hyperchat.ru` |
| `SUBDOMAIN_LIVEKIT=livekit` | `livekit` | `livekit.hyperchat.ru` |
| `SUBDOMAIN_STICKERS=stickers` | `stickers` | `stickers.hyperchat.ru` |

Leave `SUBDOMAIN_ELEMENT` empty to serve Element at the root domain (recommended).
Set any subdomain to a custom value — `make build` computes the full hostnames and propagates
them through Caddyfile generation, DNS checks, and Traefik routing automatically.

Enable optional services by setting `ENABLE_*=true`. See `.env.example` for all options.

### 3. Generate secrets

```bash
make secrets
```

Auto-generates all passwords and cryptographic keys in `.env`.
Safe to re-run — never overwrites already-set values. Backs up `.env` before each run.

### 4. Validate

```bash
make check
```

Verifies that all required settings are present and consistent before generating configs.

### 5. Build configs

```bash
make build
```

Generates `synapse/homeserver.yaml`, `element/config.json`, bridge configs, and all other
service configs from templates using your `.env`.

### 6. Set up Caddy

```bash
make caddy
```

Prints ready-to-paste Caddyfile blocks for your exact build configuration.
Copy the output into `/etc/caddy/Caddyfile`, then:

```bash
sudo systemctl reload caddy
```

### 7. Check DNS

```bash
make dns
```

Verifies that all required DNS records resolve to this server.

### 8. Start

```bash
make start
```

Pulls images and starts the full stack.

### 9. Create your admin user

```bash
make admin
```

### 10. Open Element

Go to `https://example.com` (or your domain) and sign in.

---

## Storage options

Set `STORAGE_TYPE` in `.env`:

| Value | Description |
|-------|-------------|
| `volumes` | Docker named volumes (default) |
| `local` | Bind-mount to a directory on the host — set `DATA_PATH` |
| `garage` | Local Garage container as S3 storage — auto-configured |
| `s3` | External S3-compatible storage (AWS, Cloudflare R2, Backblaze B2, etc.) |

Run `make storage` to inspect the current storage configuration after `make build`.

---

## Local dev mode

Test the stack on your PC without a domain or TLS. No configuration needed:

```bash
make dev
```

Starts Postgres + Redis + Synapse + Element Web with open registration and hardcoded passwords.

| URL | Service |
|-----|---------|
| http://localhost:8080 | Element Web |
| http://localhost:8008 | Synapse API |
| http://localhost:8082 | Synapse Admin |

> **Note:** dev mode has open registration, hardcoded passwords, no bridges, no TURN/LiveKit, no TLS.
> Never expose to the internet.

| Command | Description |
|---------|-------------|
| `make dev` | Start dev stack |
| `make dev-down` | Stop dev stack |
| `make dev-reset` | Wipe dev volumes and restart fresh |
| `make dev-status` | Dev service status dashboard |
| `make dev-logs` | Follow all dev logs |
| `make dev-logs s=NAME` | Follow logs for a specific service |
| `make dev-admin` | Create admin user in dev Synapse |
| `make dev-shell s=NAME` | Open a shell inside a dev container |

Dev data lives in separate Docker volumes and does not interfere with the production stack.

---

## Bridge setup

Bridges are disabled by default. To enable one, set the corresponding flag in `.env`:

```ini
ENABLE_BRIDGE_TELEGRAM=true
TELEGRAM_API_ID=12345
TELEGRAM_API_HASH=abcdef...

ENABLE_BRIDGE_DISCORD=true
DISCORD_BOT_TOKEN=...
```

Re-run `make build && make start` to apply.

On first startup, each bridge generates a Synapse registration file. After `make start`,
wait ~30 seconds, then restart Synapse to load the new registrations:

```bash
make restart
```

---

## All commands

Run `make` with no arguments to see the full list.

**Setup**

| Command | Description |
|---------|-------------|
| `make secrets` | Generate missing secrets in `.env` (idempotent, backs up before writing) |
| `make check` | Validate `.env` — catches missing fields and conflicts |
| `make build` | Generate all configs from `.env` |
| `make caddy` | Print ready-to-paste Caddyfile blocks for your build |
| `make storage` | Show current storage configuration |
| `make dns` | Check DNS records for all enabled services |
| `make email` | Interactive SMTP setup wizard |
| `make email-test` | Test SMTP connection |

**Lifecycle**

| Command | Description |
|---------|-------------|
| `make start` | Pull images and start all services |
| `make up` | Start services without pulling |
| `make down` | Stop all services |
| `make restart` | Restart all services |

**Updates**

| Command | Description |
|---------|-------------|
| `make pull` | Pull latest images (stack keeps running) |
| `make upgrade` | Pull latest images and restart if anything changed |

**Maintenance**

| Command | Description |
|---------|-------------|
| `make clear` | Remove dangling Docker images |
| `make prune` | Remove images not used by this stack |
| `make volumes` | Show data volumes and their sizes |
| `make reset` | Wipe all data volumes (asks for confirmation) |
| `make backup` | Dump all PostgreSQL databases to `./backups/` |

**Monitoring**

| Command | Description |
|---------|-------------|
| `make status` | Colour-coded service status dashboard |
| `make health` | Container health-check details |
| `make logs` | Follow logs for all services |
| `make logs s=NAME` | Follow logs for a specific service |

**Admin**

| Command | Description |
|---------|-------------|
| `make admin` | Create a Matrix admin user |
| `make shell s=NAME` | Open a shell inside a service container |

---

## Repository structure

```
HyperChat/
├── docker-compose.yml              # Base stack definition
├── docker-compose.dev.yml          # Local dev stack
├── docker-compose.ports.yml        # Port bindings overlay (modes 1 and 3)
├── docker-compose.traefik.yml      # Traefik routing overlay — uses HOST_* vars from .env
├── .env.example                    # Config template — copy to .env
├── Makefile
├── synapse/
│   ├── homeserver.yaml.template    # → homeserver.yaml (generated by make build)
│   ├── homeserver.dev.yaml         # Dev config (hardcoded, open registration)
│   └── log.config
├── element/
│   └── config.json.template        # → config.json
├── cinny/
│   └── config.json.template        # → config.json
├── coturn/
│   └── turnserver.conf.template    # → turnserver.conf
├── livekit/
│   └── livekit.yaml.template       # → livekit.yaml
├── garage/
│   └── garage.toml.template        # → garage.toml
├── traefik/
│   └── traefik.yml.template        # → traefik.yml
├── bridges/
│   ├── telegram/config.yaml.template
│   ├── whatsapp/config.yaml.template
│   ├── discord/config.yaml.template
│   └── signal/config.yaml.template
├── postgres/
│   └── init-databases.sh           # Creates per-bridge databases on first run
└── stickerpicker/
    └── index.html
```

---

## Security

- All generated config files contain real secrets. Do **not** commit `.env` or any generated `*.yaml`/`*.toml`/`*.conf` files.
- Synapse Admin is always bound to `127.0.0.1` — never exposed publicly regardless of deploy mode.
- Access it via an SSH tunnel: `ssh -L 8082:localhost:8082 user@yourserver`, then open `http://localhost:8082`.

---

## License

[MIT](LICENSE)
