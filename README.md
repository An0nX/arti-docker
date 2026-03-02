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
- **🔄 Auto-updated:** CI checks for new upstream commits every hour and rebuilds automatically.
- **🧰 Build-time pinning:** Upstream repo/ref are configurable via build args.

---

## ⚠️ Important Notice

Arti is a Tor client. Using Tor may be restricted, monitored, or illegal depending on your jurisdiction. Operating Tor relays, bridges, or onion services carries additional legal and operational considerations.

**You are responsible for compliance with local laws** and for safe deployment (firewalling, access control, logging, monitoring).

Arti is under **active development** by The Tor Project. While functional, it may not yet have full feature parity with the C Tor implementation. Check the [upstream status](https://gitlab.torproject.org/tpo/core/arti) before production use.

---

## 🚀 Quick Start

### Docker Compose (recommended)

Create `docker-compose.yml`:

```yaml
services:
  arti:
    image: whn0thacked/arti-docker:latest
    container_name: arti
    restart: unless-stopped
    environment:
      RUST_LOG: "info"
    ports:
      - "127.0.0.1:9050:9050/tcp"
      # - "127.0.0.1:9053:9053/tcp"
      # - "127.0.0.1:9053:9053/udp"
    volumes:
      - arti-data:/var/lib/arti
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    read_only: true
    tmpfs:
      - /tmp:rw,nosuid,nodev,noexec,size=64m
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.1"
          memory: 128M
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "5"
        compress: "true"
    stop_grace_period: 30s

volumes:
  arti-data:
```

```bash
docker compose up -d
```

Verify:

```bash
curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip
# {"IsTor":true,"IP":"xxx.xxx.xxx.xxx"}
```

### Docker Run (one-liner)

```bash
docker run -d --name arti \
  -p 127.0.0.1:9050:9050 \
  -v arti-data:/var/lib/arti \
  --read-only --tmpfs /tmp:rw,nosuid,nodev,noexec,size=64m \
  --security-opt no-new-privileges:true --cap-drop ALL \
  --memory 512m --cpus 1.0 \
  --restart unless-stopped \
  whn0thacked/arti-docker:latest
```

---

## ⚙️ Configuration Reference

### Environment Variables

| Variable | Required | Default | Description |
|---|:---:|---|---|
| `RUST_LOG` | No | `info` (built-in) | Log level filter. Supports per-module granularity. |

**`RUST_LOG` examples:**

| Value | Effect |
|---|---|
| `info` | Default — recommended for production |
| `debug` | Verbose — troubleshooting |
| `warn` | Quiet — only problems |
| `arti=debug,tor_proto=info` | Per-module granularity |
| `trace` | Extreme verbosity (development only) |

### CLI Parameters (Global)

| Parameter | Short | Description |
|---|---|---|
| `--config FILE` | `-c` | Load configuration from file. Can be specified multiple times. |
| `--option KEY=VALUE` | `-o` | Override config values using TOML syntax. Can be specified multiple times. |
| `--log-level LEVEL` | `-l` | Override log level (`trace`, `debug`, `info`, `warn`, `error`). |
| `--disable-fs-permission-checks` | — | Disable filesystem permission checks (enabled by default in this image). |

### CLI Parameters (`proxy` subcommand)

| Parameter | Short | Description |
|---|---|---|
| `--socks-port PORT` | `-p` | Override SOCKS listen port (default: `9050`). |
| `--dns-port PORT` | — | Override DNS listen port (default: `9053`). |

### Subcommands

| Subcommand | Description |
|---|---|
| `proxy` | Run the SOCKS/DNS proxy **(default)**. |
| `keys list` | List all keys. |
| `keys list-keystores` | List key storage backends. |
| `keys check-integrity` | Verify key integrity. |
| `hsc key get` | Get onion service key. |
| `hsc key list` | List onion service keys. |
| `hss` | Hidden service server operations. |

### Ports

| Port | Protocol | Purpose |
|---:|---|---|
| `9050` | TCP | SOCKS5 proxy — main Tor entry point. |
| `9053` | TCP/UDP | DNS resolver — anonymized DNS queries over Tor. |
| `9150` | TCP | Alternative SOCKS5 port (Tor Browser convention). |

### Volumes

| Container Path | Purpose | Backup |
|---|---|---|
| `/var/lib/arti` | Persistent state: consensus cache, descriptors, guard state. Safe to delete — re-bootstraps in 30s–2min. | Optional |
| `/var/lib/arti/keys` | Cryptographic keys: onion service identity, client auth. **Losing = losing .onion address.** | **Critical** |
| `/etc/arti.toml` | Configuration file (optional — mount from host as read-only). | Optional |

---

## 🧠 Container Behavior

- **ENTRYPOINT:** `/usr/local/bin/arti`
- **CMD (default):**

```text
proxy --disable-fs-permission-checks \
  -o "proxy.socks_listen=[\"0.0.0.0:9050\"]" \
  -o "proxy.dns_listen=[\"0.0.0.0:9053\"]"
```

The container runs a SOCKS5 proxy on `9050` and a DNS resolver on `9053`, listening on all interfaces inside the container.

Override by passing your own arguments:

```bash
docker run ... whn0thacked/arti-docker:latest proxy -c /etc/arti.toml
docker run ... whn0thacked/arti-docker:latest proxy --socks-port 1080
docker run ... whn0thacked/arti-docker:latest keys list
```

---

## 📝 Advanced Usage

### Custom config file

```bash
docker run -d --name arti \
  -p 127.0.0.1:9050:9050 \
  -v ./arti.toml:/etc/arti.toml:ro \
  -v arti-data:/var/lib/arti \
  --read-only --tmpfs /tmp:rw,nosuid,nodev,noexec,size=64m \
  --security-opt no-new-privileges:true --cap-drop ALL \
  whn0thacked/arti-docker:latest \
  proxy --disable-fs-permission-checks -c /etc/arti.toml
```

### CLI overrides (no config file needed)

```bash
docker run -d --name arti \
  -p 127.0.0.1:9050:9050 \
  -p 127.0.0.1:9053:9053 \
  whn0thacked/arti-docker:latest \
  proxy \
  --disable-fs-permission-checks \
  -o 'proxy.socks_listen=["0.0.0.0:9050"]' \
  -o 'proxy.dns_listen=["0.0.0.0:9053"]' \
  -l debug
```

### DNS resolution over Tor

```bash
# Enable DNS port in compose or docker run:
# -p 127.0.0.1:9053:9053/tcp -p 127.0.0.1:9053:9053/udp

dig @127.0.0.1 -p 9053 torproject.org
nslookup torproject.org 127.0.0.1 -port=9053
```

### Use with applications

```bash
# curl
curl --socks5-hostname 127.0.0.1:9050 https://example.onion

# Environment variable (works with many apps)
ALL_PROXY=socks5h://127.0.0.1:9050 curl https://check.torproject.org/api/ip

# proxychains
echo "socks5 127.0.0.1 9050" >> /etc/proxychains.conf
proxychains curl https://check.torproject.org/api/ip

# Firefox: Settings → Network → Manual Proxy → SOCKS Host: 127.0.0.1:9050
# ✅ Check "Proxy DNS when using SOCKS v5"
```

---

## 🧅 Onion Services

### Running an onion service

Create `arti.toml` with onion service config (see [upstream docs](https://tpo.pages.torproject.net/core/arti/)):

```bash
docker run -d --name arti-hs \
  -v ./arti.toml:/etc/arti.toml:ro \
  -v arti-keys:/var/lib/arti/keys \
  -v arti-data:/var/lib/arti \
  --read-only --tmpfs /tmp:rw,nosuid,nodev,noexec,size=64m \
  --security-opt no-new-privileges:true --cap-drop ALL \
  whn0thacked/arti-docker:latest \
  proxy --disable-fs-permission-checks -c /etc/arti.toml
```

### Key management

```bash
docker run --rm whn0thacked/arti-docker:latest keys list
docker run --rm whn0thacked/arti-docker:latest keys list-keystores
docker run --rm whn0thacked/arti-docker:latest keys check-integrity

# With mounted keys volume:
docker run --rm -v arti-keys:/var/lib/arti/keys:ro \
  whn0thacked/arti-docker:latest hsc key list
```

---

## 🛡️ Security Hardening

This image applies the following hardening measures:

| Measure | Description |
|---|---|
| **Distroless base** | No shell, no package manager, no utilities — minimal attack surface |
| **Non-root** | Runs as UID 65534 (`nonroot`) |
| **Static binary** | No dynamic linker, no shared libraries |
| **Read-only FS** | Root filesystem is read-only; `/tmp` via tmpfs |
| **No capabilities** | All Linux capabilities dropped (`cap_drop: ALL`) |
| **No privilege escalation** | `no-new-privileges` prevents setuid/setgid abuse |
| **Resource limits** | CPU and memory limits prevent DoS |
| **Log rotation** | Prevents disk exhaustion |
| **SIGINT shutdown** | Graceful shutdown via `STOPSIGNAL SIGINT` |
| **Localhost binding** | Ports bound to `127.0.0.1` by default in examples |

---

## 🛠 Build

This Dockerfile supports pinning upstream Arti source:

- `ARTI_REPO` (default: `https://gitlab.torproject.org/tpo/core/arti.git`)
- `ARTI_REF` (default: `main`)

### Multi-arch build

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t whn0thacked/arti-docker:latest \
  --push .
```

### Build a specific commit

```bash
docker buildx build \
  --build-arg ARTI_REF=ba4163ed943a67cd8a55f7291797fb22a788f950 \
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
- **Arti example config:** https://gitlab.torproject.org/tpo/core/arti/-/raw/main/crates/arti/src/arti-example-config.toml
- **Tor Project:** https://www.torproject.org/
- **Distroless images:** https://github.com/GoogleContainerTools/distroless

---

## 📄 License

This Dockerfile, CI pipeline, and associated documentation are licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).

Arti itself is licensed under **MIT OR Apache-2.0** by [The Tor Project](https://www.torproject.org/).
