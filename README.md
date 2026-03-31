# 🔥 HyperChat

**Self-hosted Matrix server in one `docker compose up` — everything you need for a private messenger, ready to go.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What's included

| Service | Image | Purpose |
|---------|-------|---------|
| **Synapse** | `matrixdotorg/synapse:latest` | Matrix homeserver |
| **PostgreSQL 16** | `postgres:16-alpine` | Primary database |
| **Redis 7** | `redis:7-alpine` | Cache & worker coordination |
| **Element Web** | `vectorim/element-web:latest` | Web client |
| **Synapse Admin** | `awesometechnologies/synapse-admin:latest` | Admin panel |
| **mautrix-telegram** | `dock.mau.dev/mautrix/telegram:latest` | Telegram bridge |
| **mautrix-whatsapp** | `dock.mau.dev/mautrix/whatsapp:latest` | WhatsApp bridge |
| **mautrix-discord** | `dock.mau.dev/mautrix/discord:latest` | Discord bridge |
| **mautrix-signal** | `dock.mau.dev/mautrix/signal:latest` | Signal bridge |
| **Coturn** | `coturn/coturn:latest` | TURN/STUN for 1-to-1 calls |
| **LiveKit** | `livekit/livekit-server:latest` | Group video calls |
| **nginx** | `nginx:alpine` | Sticker picker host |

**Matrix Media Repo** (`turt2live/matrix-media-repo`) is included but commented out — see `docker-compose.yml` for instructions.

---

## Quick start

### Prerequisites

- Docker Engine 24+ and Docker Compose v2
- GNU Make 4.0+ (`apt install make`)
- [Caddy](https://caddyserver.com) installed as a system package (handles TLS)
- `envsubst` (`apt install gettext-base`)
- A domain with DNS pointing to your server

### 1. Clone

```bash
git clone https://github.com/Mimic890/HyperChat.git
cd HyperChat
```

### 2. Configure

```bash
cp .env.example .env
nano .env   # set DOMAIN, COTURN_EXTERNAL_IP, Telegram/Discord API keys
```

### 3. Generate secrets

```bash
make secrets
```

Auto-generates all passwords and cryptographic secrets in `.env`.
Safe to re-run — never overwrites already-set values. Backs up `.env` before each run.

### 4. Apply config

```bash
make build
```

Substitutes `${VARIABLE}` placeholders in all config files using your `.env`.

### 5. Set up Caddy

Copy the relevant blocks from [`docs/Caddyfile.example`](docs/Caddyfile.example)
into your `/etc/caddy/Caddyfile`, then:

```bash
sudo systemctl reload caddy
```

### 6. Start

```bash
make up
```

### 7. Create your admin user

```bash
make admin
```

### 8. Open Element

Go to `https://element.yourdomain.com` and sign in.

---

## Local dev mode

Want to test the stack on your PC without a domain or TLS? No configuration needed:

```bash
make dev
```

That's it. Docker pulls the images and starts Postgres + Redis + Synapse + Element Web.

| URL | Service |
|-----|---------|
| http://localhost:8080 | Element Web |
| http://localhost:8008 | Synapse API |
| http://localhost:8082 | Synapse Admin |

> **Dev mode differences:** open user registration, hardcoded passwords,
> no bridges, no TURN/LiveKit, no TLS. Never expose to the internet.

| Command | Description |
|---------|-------------|
| `make dev` | Start local dev stack |
| `make dev-down` | Stop dev stack |
| `make dev-reset` | Wipe dev volumes and start fresh |
| `make dev-status` | Dev service status dashboard |
| `make dev-logs` | Follow all dev logs |
| `make dev-logs s=NAME` | Follow logs for a specific dev service |
| `make dev-admin` | Create admin user in dev Synapse |
| `make dev-shell s=NAME` | Open a shell inside a dev service container |

Dev data lives in separate Docker volumes (`postgres_dev_data`, `synapse_dev_data`)
and does not interfere with the production stack.

---

## First-run bridge setup

Bridges generate their Synapse registration files on first startup.
After `make up`, wait ~30 seconds, then restart Synapse:

```bash
make restart
```

See [docs/bridges.md](docs/bridges.md) for configuring each bridge.

---

## Makefile commands

Run `make` with no arguments to see the full command list.

| Command | Description |
|---------|-------------|
| `make secrets` | Auto-generate missing secrets in `.env` (idempotent, backs up existing) |
| `make build` | Substitute `.env` values into all config files |
| `make up` | Start all services |
| `make down` | Stop all services |
| `make restart` | Restart all services |
| `make update` | Pull latest Docker images (no restart) |
| `make upgrade` | Pull latest images and restart if anything changed |
| `make clear` | Remove unused / dangling Docker images |
| `make backup` | Dump all PostgreSQL databases to `./backups/` |
| `make status` | Colour-coded service status dashboard |
| `make health` | Container health-check details (shows failing health log) |
| `make logs` | Follow logs for all services |
| `make logs s=NAME` | Follow logs for a specific service |
| `make admin` | Create a Matrix admin user |
| `make shell s=NAME` | Open a shell inside a service container |

---

## Documentation

| Doc | Content |
|-----|---------|
| [docs/setup.md](docs/setup.md) | Full step-by-step installation guide |
| [docs/bridges.md](docs/bridges.md) | Configuring Telegram, WhatsApp, Discord, Signal |
| [docs/voip.md](docs/voip.md) | Coturn and LiveKit setup |
| [docs/stickers.md](docs/stickers.md) | Importing and hosting sticker packs |
| [docs/monitoring.md](docs/monitoring.md) | Prometheus metrics endpoints |
| [docs/federation.md](docs/federation.md) | DNS, well-known, federation testing |
| [docs/Caddyfile.example](docs/Caddyfile.example) | Ready-to-use Caddy config |

---

## Repository structure

```
hyperchat/
├── docker-compose.yml          # Production stack
├── docker-compose.dev.yml      # Local dev stack (no domain, no TLS)
├── .env.example
├── Makefile                    # All management commands
├── docs/
│   ├── Caddyfile.example
│   ├── setup.md
│   ├── bridges.md
│   ├── voip.md
│   ├── stickers.md
│   ├── monitoring.md
│   └── federation.md
├── synapse/
│   ├── homeserver.yaml         # Production config (run: make build)
│   ├── homeserver.dev.yaml     # Dev config (hardcoded, open registration)
│   └── log.config
├── element/
│   ├── config.json             # Production (points to https://matrix.DOMAIN)
│   └── config.dev.json         # Dev (points to http://localhost:8008)
├── bridges/
│   ├── telegram/config.yaml
│   ├── whatsapp/config.yaml
│   ├── discord/config.yaml
│   └── signal/config.yaml
├── coturn/
│   └── turnserver.conf
├── livekit/
│   └── livekit.yaml
├── stickerpicker/
│   └── index.html
└── postgres/
    └── init-databases.sh
```

---

## Security notice

After running `make build`, your config files contain real secrets and passwords.
Do **not** push a modified copy of this repository to a public host.

---

## License

[MIT](LICENSE) — © 2026 mimic_8
