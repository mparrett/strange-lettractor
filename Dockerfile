# syntax=docker/dockerfile:1
#
# strange-lettractor container build: bin/attractor, run as `attractor serve`.
#
# Three stages, mirroring README "Prerequisites":
#   1. runtime — the pinned, patched let-go fork compiled to a static `lg`
#   2. app     — lgx installs tiny-tui and bundles main.lg into bin/attractor
#   3. final   — a slim image carrying only bin/attractor plus the tools it
#                shells out to at run time
#
# Every stage is pinned to linux/amd64 on purpose: the deploy target is an amd64
# node and the usual build host is an arm64 Mac. bin/attractor is a copy of the
# lg that bundled it (`lg -b` copies the running executable as the bundle base),
# so the lg built in stage 1 must already be the target platform's binary.
# PLATFORM is an ARG only so the lint is happy and a deliberate override is
# possible; the default is the deploy target.

ARG PLATFORM=linux/amd64
ARG LETGO_REPO=https://github.com/nnunley/let-go.git
ARG LETGO_SHA=46244c4fa8169b8138aa1c29f31c8a6102ed1755
ARG LGX_VERSION=0.2.1
ARG GO_IMAGE=golang:1.26.5-bookworm
ARG BASE_IMAGE=debian:bookworm-slim

# ---------------------------------------------------------------------------
# 1. runtime: patched let-go at the pinned revision
# ---------------------------------------------------------------------------
FROM --platform=${PLATFORM} ${GO_IMAGE} AS runtime
ARG LETGO_REPO
ARG LETGO_SHA
WORKDIR /src/let-go
# Fetch exactly the pinned commit rather than cloning history; GitHub serves
# arbitrary reachable SHAs, so this stays reproducible without a branch name.
RUN git init -q . \
 && git remote add origin "${LETGO_REPO}" \
 && git fetch -q --depth 1 origin "${LETGO_SHA}" \
 && git checkout -q --detach FETCH_HEAD
COPY runtime-patches/ /src/runtime-patches/
RUN git apply --check /src/runtime-patches/net-listener.patch /src/runtime-patches/json-string-keys.patch \
 && git apply /src/runtime-patches/net-listener.patch /src/runtime-patches/json-string-keys.patch
# CGO off: let-go has no cgo dependencies, and a static binary is what lets the
# final stage be a slim Debian rather than a matching glibc toolchain image.
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -o /out/lg .

# ---------------------------------------------------------------------------
# 2. app: lgx install + lgx build against the patched runtime
# ---------------------------------------------------------------------------
FROM --platform=${PLATFORM} ${BASE_IMAGE} AS app
ARG LGX_VERSION
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git \
 && rm -rf /var/lib/apt/lists/*
# lgx ships prebuilt release binaries; verify against the release checksums.
# The download lands on a tmpfs mount so nothing stays in the layer.
RUN --mount=type=tmpfs,target=/dl \
    set -eu; cd /dl; \
    tarball="lgx_${LGX_VERSION}_linux_amd64.tar.gz"; \
    base="https://github.com/abogoyavlensky/lgx/releases/download/v${LGX_VERSION}"; \
    curl -fsSLO "${base}/${tarball}"; curl -fsSLO "${base}/checksums.txt"; \
    grep " ${tarball}\$" checksums.txt | sha256sum -c -; \
    tar -xzf "${tarball}"; \
    install -m 0755 "$(find . -maxdepth 2 -type f -name lgx | head -1)" /usr/local/bin/lgx
COPY --from=runtime /out/lg /usr/local/bin/lg
# lgx.edn pins :lg-version 1.12.2 for the stock runtime; the patched fork build
# reports a dev version, and the Makefile's LGX_LG override is the documented
# way to run against it. Skip the pin check for the same reason.
ENV LGX_LG=/usr/local/bin/lg \
    LGX_SKIP_VERSION_CHECK=1
WORKDIR /src/app
COPY lgx.edn main.lg ./
COPY src/ src/
RUN lgx install && lgx build \
 && test -x bin/attractor \
 && bin/attractor help >/dev/null

# ---------------------------------------------------------------------------
# 3. final: the binary plus what it execs at run time
# ---------------------------------------------------------------------------
FROM --platform=${PLATFORM} ${BASE_IMAGE}
# What bin/attractor shells out to (src/attractor/*.lg, os/sh): bash, sh,
# coreutils (rm/mkdir/mv/stat/mktemp/test/kill), pkill (procps), openssl, and
# git for the project skills root. ca-certificates for HTTPS to model
# providers. graphviz supplies `dot` for `attractor graph` and GET /pipelines/<id>/graph.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git graphviz openssl procps \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --uid 10001 --create-home --shell /usr/sbin/nologin attractor \
 && install -d -o attractor -g attractor /data
COPY --from=app /src/app/bin/attractor /usr/local/bin/attractor
# Everything the server writes is relative to the working directory
# (attractor_runs/, .attractor/, .nrepl-port) or under $ATTRACTOR_HOME, so one
# writable /data covers the lot; the rest of the filesystem can be read-only.
# It also reads an optional .env and attractor.edn from here.
ENV ATTRACTOR_HOME=/data
WORKDIR /data
VOLUME ["/data"]
USER attractor
# `serve` binds the http/serve address given by --port (Go ListenAndServe
# syntax; ":7070" is every interface). Its nREPL hub stays on 127.0.0.1.
EXPOSE 7070
ENTRYPOINT ["attractor"]
CMD ["serve", "--port", ":7070"]
