# syntax=docker/dockerfile:1.7

ARG ARTI_REPO=https://gitlab.torproject.org/tpo/core/arti.git
ARG ARTI_REF=main

# ───────────────────────────────────────────────────────────
#  Stage 1 — build
# ───────────────────────────────────────────────────────────
FROM --platform=$TARGETPLATFORM rustlang/rust:nightly-alpine AS build

ARG ARTI_REPO
ARG ARTI_REF

ENV CARGO_NET_GIT_FETCH_WITH_CLI=true \
    CARGO_TERM_COLOR=always \
    CARGO_PROFILE_RELEASE_LTO=true \
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 \
    CARGO_PROFILE_RELEASE_DEBUG=false \
    CARGO_PROFILE_RELEASE_STRIP=true \
    CARGO_PROFILE_RELEASE_DEBUG_ASSERTIONS=false \
    CARGO_PROFILE_RELEASE_OVERFLOW_CHECKS=false \
    CARGO_PROFILE_RELEASE_PANIC=abort \
    OPENSSL_STATIC=1 \
    SQLITE3_STATIC=1 \
    RUSTFLAGS="-C target-cpu=generic -C link-arg=-static-libgcc"

WORKDIR /src

RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache \
      ca-certificates git \
      build-base musl-dev pkgconf perl make \
      binutils \
      openssl-dev openssl-libs-static \
      sqlite-dev sqlite-static \
      zlib-dev zlib-static \
      protobuf-dev \
    && update-ca-certificates

RUN --mount=type=cache,target=/root/.cache/git \
    git clone --depth=1 --branch "${ARTI_REF}" "${ARTI_REPO}" . \
    || (git init . && git remote add origin "${ARTI_REPO}" \
        && git fetch --depth=1 origin "${ARTI_REF}" \
        && git checkout --detach FETCH_HEAD)

RUN rustup component add rust-src

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/src/target \
    set -eux; \
    \
    RUST_TARGET="$(rustc -vV | sed -n 's|host: ||p')"; \
    \
    if [ ! -f Cargo.lock ]; then cargo generate-lockfile; fi; \
    \
    RUSTFLAGS="${RUSTFLAGS} -Zunstable-options -Cpanic=immediate-abort" \
    cargo build \
      -p arti \
      --release \
      --locked \
      --all-features \
      --target "${RUST_TARGET}" \
      -Z build-std=std,core,alloc,panic_abort; \
    \
    mkdir -p /out; \
    install -Dm755 "target/${RUST_TARGET}/release/arti" /out/arti; \
    strip /out/arti; \
    \
    if readelf -lW /out/arti | grep -q "Requesting program interpreter"; then \
      echo "ERROR: arti is dynamically linked — cannot run in distroless/static"; \
      exit 1; \
    fi

RUN mkdir -p /tmp/arti/cache /tmp/arti/state && \
    chmod 755 /tmp/arti /tmp/arti/cache /tmp/arti/state

# ───────────────────────────────────────────────────────────
#  Stage 2 — runtime
# ───────────────────────────────────────────────────────────
FROM gcr.io/distroless/static:nonroot AS runtime

LABEL org.opencontainers.image.title="Arti" \
      org.opencontainers.image.description="A Rust Tor implementation - lightweight, safe, and efficient" \
      org.opencontainers.image.source="https://gitlab.torproject.org/tpo/core/arti.git" \
      org.opencontainers.image.url="https://tpo.pages.torproject.net/core/arti/" \
      org.opencontainers.image.documentation="https://tpo.pages.torproject.net/core/arti/" \
      org.opencontainers.image.licenses="MIT OR Apache-2.0"

STOPSIGNAL SIGINT

COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /out/arti /usr/local/bin/arti

COPY --from=build --chown=65532:65532 --chmod=755 /tmp/arti /tmp/arti

WORKDIR /tmp

EXPOSE 9050/tcp 9053/udp 9053/tcp 9150/tcp

USER nonroot:nonroot
ENTRYPOINT ["/usr/local/bin/arti"]
CMD ["proxy", \
     "--disable-fs-permission-checks", \
     "-o", "proxy.socks_listen=[\"0.0.0.0:9050\"]", \
     "-o", "proxy.dns_listen=[\"0.0.0.0:9053\"]", \
     "-o", "storage.cache_dir=\"/tmp/arti/cache\"", \
     "-o", "storage.state_dir=\"/tmp/arti/state\""]
