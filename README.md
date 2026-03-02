# 🐳 arti-docker

[![Docker Image Size](https://img.shields.io/docker/image-size/whn0thacked/arti-docker?style=flat-square&logo=docker&color=blue)](https://hub.docker.com/r/whn0thacked/arti-docker)
[![Docker Pulls](https://img.shields.io/docker/pulls/whn0thacked/arti-docker?style=flat-square&logo=docker)](https://hub.docker.com/r/whn0thacked/arti-docker)
[![Architecture](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-important?style=flat-square)](#)
[![Security: non-root](https://img.shields.io/badge/security-non--root-success?style=flat-square)](#)
[![Base Image](https://img.shields.io/badge/base-distroless%2Fstatic%3Anonroot-blue?style=flat-square)](https://github.com/GoogleContainerTools/distroless)
[![Upstream](https://img.shields.io/badge/upstream-Arti%20(Tor%20Project)-7D4698?style=flat-square)](https://gitlab.torproject.org/tpo/core/arti)

A minimal, secure, and production-oriented Docker image for **Arti** — a complete rewrite of the Tor client in **Rust**, developed by [The Tor Project](https://www.torproject.org/).

Built as a **fully static** binary with **all features enabled** and shipped in a **distroless** runtime image, running as **non-root** by default.

---

## ✨ Features

- **🔐 Secure by default:** Distroless runtime + non-root user + static binary.
- **🏗 Multi-arch:** Supports `amd64` and `arm64`.
- **📦 Fully static binary:** Built for `gcr.io/distroless/static:nonroot` — no libc, no dynamic linker.
- **🌐 Full-featured:** Built with `--all-features` — SOCKS proxy, DNS resolver, onion services (client & server), pluggable transports, RPC, key management.
- **🧾 Config-driven:** Mount a TOML config or configure entirely via CLI flags.
- **🔄 Auto-updated:** CI checks for new upstream releases every hour and rebuilds automatically.
- **🧰 Build-time pinning:** Upstream repo/ref are configurable via build args.

---

## ⚠️ Important Notice

Arti is a Tor client. Using Tor may be restricted, monitored, or illegal depending on your jurisdiction. Operating Tor relays, bridges, or onion services carries additional legal and operational considerations.

**You are responsible for compliance with local laws** and for safe deployment (firewalling, access control, logging, monitoring).

Arti is under **active development** by The Tor Project. While functional, it may not yet have full feature parity with the C Tor implementation. Check the [upstream status](https://gitlab.torproject.org/tpo/core/arti) before production use.

---

## 🚀 Quick Start (Docker Compose)

### 1. Create `docker-compose.yml`

The container works **out of the box** with sensible defaults — no config file required.

```yaml
services:
  arti:
    image: whn0thacked/arti-docker:latest
    container_name: arti
    restart: unless-stopped

    environment:
      RUST_LOG: "info"

    ports:
      # SOCKS5 proxy
      - "9050:9050/tcp"
      # DNS resolver (optional)
      # - "9053:9053/tcp"
      # - "9053:9053/udp"

    # Hardening
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    read_only: true
    tmpfs:
      - /tmp:rw,nosuid,nodev,noexec,size=64m

    # Persistent Tor state (consensus cache, keys, etc.)
    volumes:
      - arti-data:/var/lib/arti

    # Resource limits (optional)
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M

    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  arti-data:
```

### 2. Start

```bash
docker compose up -d
```

### 3. Verify Tor is working

```bash
curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip
```

Expected response:

```json
{"IsTor":true,"IP":"xxx.xxx.xxx.xxx"}
```

### 4. Logs

```bash
docker compose logs -f
```

---

## 📝 Advanced: Custom Configuration

### With a config file

Create `arti.toml` (see [upstream documentation](https://tpo.pages.torproject.net/core/arti/) for format):

```yaml
services:
  arti:
    image: whn0thacked/arti-docker:latest
    container_name: arti
    restart: unless-stopped

    volumes:
      - ./arti.toml:/etc/arti.toml:ro
      - arti-data:/var/lib/arti

    ports:
      - "9050:9050/tcp"

    # Override CMD to use config file
    command: ["proxy", "--disable-fs-permission-checks", "-c", "/etc/arti.toml"]

    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    read_only: true
    tmpfs:
      - /tmp:rw,nosuid,nodev,noexec,size=64m

volumes:
  arti-data:
```

### With CLI overrides

```bash
docker run -d --name arti \
  -p 9050:9050 \
  whn0thacked/arti-docker:latest \
  proxy \
  --disable-fs-permission-checks \
  -o "proxy.socks_listen=[\"0.0.0.0:9050\"]" \
  -o "proxy.dns_listen=[\"0.0.0.0:9053\"]" \
  -l info
```

---

## 🧅 Onion Services (Hidden Services)

### Running an onion service

Create `arti-hs.toml` with your onion service configuration, then:

```yaml
services:
  arti-hs:
    image: whn0thacked/arti-docker:latest
    container_name: arti-hs
    restart: unless-stopped

    volumes:
      - ./arti-hs.toml:/etc/arti.toml:ro
      - arti-keys:/var/lib/arti/keys

    command: ["proxy", "--disable-fs-permission-checks", "-c", "/etc/arti.toml"]

    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    read_only: true
    tmpfs:
      - /tmp:rw,nosuid,nodev,noexec,size=64m

volumes:
  arti-keys:
```

### Key management

```bash
# List keys
docker run --rm whn0thacked/arti-docker:latest keys list

# List keystores
docker run --rm whn0thacked/arti-docker:latest keys list-keystores

# Check key integrity
docker run --rm whn0thacked/arti-docker:latest keys check-integrity

# List onion service keys
docker run --rm \
  -v arti-keys:/var/lib/arti/keys:ro \
  whn0thacked/arti-docker:latest \
  hsc key list
```

---

## ⚙️ Configuration

### Environment Variables

| Variable | Required | Default | Description |
|---|:---:|---|---|
| `RUST_LOG` | No | — | Log level filter (e.g. `info`, `debug`, `trace`, `arti=debug,tor_proto=info`). |

### CLI Parameters

| Parameter | Short | Description |
|---|---|---|
| `--config FILE` | `-c` | Load configuration from file. Can be specified multiple times. |
| `--option KEY=VALUE` | `-o` | Override config values using TOML syntax. Can be specified multiple times. |
| `--log-level LEVEL` | `-l` | Override log level (`trace`, `debug`, `info`, `warn`, `error`). |
| `--disable-fs-permission-checks` | — | Disable filesystem permission checks (recommended in containers). |

### Subcommands

| Subcommand | Description |
|---|---|
| `proxy` | Run the SOCKS/DNS proxy (default). |
| `keys list` | List keys. |
| `keys list-keystores` | List keystores. |
| `keys check-integrity` | Check key integrity. |
| `hsc key get` | Get onion service key. |
| `hsc key list` | List onion service keys. |
| `hss` | Hidden service server operations. |

### Ports

| Port | Protocol | Purpose |
|---:|---|---|
| `9050` | TCP | SOCKS5 proxy (main Tor entry point). |
| `9053` | TCP/UDP | DNS resolver (anonymized DNS over Tor). |
| `9150` | TCP | Alternative SOCKS5 port (Tor Browser convention). |

### Volumes

| Container Path | Purpose |
|---|---|
| `/etc/arti.toml` | Configuration file (optional — mount from host). |
| `/var/lib/arti` | Persistent state: consensus cache, descriptors, keys. |

---

## 🧠 Container Behavior

- **ENTRYPOINT:** `/usr/local/bin/arti`
- **CMD (default):**

```text
proxy --disable-fs-permission-checks \
  -o "proxy.socks_listen=[\"0.0.0.0:9050\"]" \
  -o "proxy.dns_listen=[\"0.0.0.0:9053\"]"
```

So the container effectively runs a SOCKS5 proxy on port `9050` and a DNS resolver on port `9053`, listening on all interfaces.

To override, pass your own subcommand and arguments:

```bash
docker run ... whn0thacked/arti-docker:latest proxy -c /etc/arti.toml
```

---

## 🛠 Build

This Dockerfile supports pinning upstream Arti source:

- `ARTI_REPO` (default: `https://gitlab.torproject.org/tpo/core/arti.git`)
- `ARTI_REF` (default: `main`)

### Multi-arch build (amd64 + arm64)

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t whn0thacked/arti-docker:latest \
  --push .
```

### Build a specific upstream tag

```bash
docker buildx build \
  --build-arg ARTI_REF=arti-v1.4.0 \
  -t whn0thacked/arti-docker:arti-v1.4.0 \
  --push .
```

### Build from a specific commit

```bash
docker buildx build \
  --build-arg ARTI_REF=abc123def456 \
  -t whn0thacked/arti-docker:dev \
  --push .
```

### Local test build

```bash
docker buildx build --load -t arti:test .
docker run --rm arti:test --version
```

> **Note:** First build takes **15–40 minutes** due to LTO, `build-std`, and all features. Subsequent builds are faster thanks to BuildKit cache.

---

## 🔗 Useful Links

- **Arti upstream:** https://gitlab.torproject.org/tpo/core/arti
- **Arti documentation:** https://tpo.pages.torproject.net/core/arti/
- **Tor Project:** https://www.torproject.org/
- **Distroless images:** https://github.com/GoogleContainerTools/distroless

---

## 📄 License

This Dockerfile, CI pipeline, and associated documentation are licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).

Arti itself is licensed under **MIT OR Apache-2.0** by [The Tor Project](https://www.torproject.org/).
