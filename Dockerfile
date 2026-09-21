# syntax=docker/dockerfile:1
#
# strange-lettractor container build: bin/attractor, run as `attractor serve`.
#
# Two stages, mirroring README "Prerequisites":
#   1. app   — the released lg and lgx, then lgx installs tiny-tui and bundles
#              main.lg into bin/attractor
#   2. final — a slim image carrying only bin/attractor plus the tools it
#              shells out to at run time
#
# Every stage is pinned to linux/amd64 on purpose: the deploy target is an amd64
# node and the usual build host is an arm64 Mac. bin/attractor is a copy of the
# lg that bundled it (`lg -b` copies the running executable as the bundle base),
# so the lg installed in stage 1 must already be the target platform's binary.
# PLATFORM is an ARG only so the lint is happy and a deliberate override is
# possible; the default is the deploy target.

ARG PLATFORM=linux/amd64
# Keep LETGO_VERSION equal to lgx.edn's :lg-version. lgx checks the two match
# and neither downloads lg nor puts it on PATH, so this is how the runtime gets
# into the image. 1.13.0 is also the floor: it is the first release carrying
# net/listen, net/accept and net/local-address (nooga/let-go#896) and the JSON
# string-key fix (#820), which auth.lg and nrepl_server.lg need.
ARG LETGO_VERSION=1.13.0
# 0.3.1 ports lgx's bundled test harness to let-go's clojure.test (lgx#52).
# Earlier lgx cannot run `lgx test` against 1.13.0 at all.
ARG LGX_VERSION=0.3.1
ARG BASE_IMAGE=debian:bookworm-slim

# ---------------------------------------------------------------------------
# 1. app: released lg + lgx, then lgx install + lgx build
# ---------------------------------------------------------------------------
FROM --platform=${PLATFORM} ${BASE_IMAGE} AS app
ARG LETGO_VERSION
ARG LGX_VERSION
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git \
 && rm -rf /var/lib/apt/lists/*
# Both projects ship prebuilt release binaries; verify against the release
# checksums. Downloads land on a tmpfs mount so nothing stays in the layer.
# Installing the published artifact rather than building let-go from source
# keeps the image on the exact bytes of the release and means the image does
# not have to track let-go's Go toolchain floor, which moved to 1.27 in 1.13.0.
RUN --mount=type=tmpfs,target=/dl \
    set -eu; cd /dl; \
    tarball="let-go_${LETGO_VERSION}_linux_amd64.tar.gz"; \
    base="https://github.com/nooga/let-go/releases/download/v${LETGO_VERSION}"; \
    curl -fsSLO "${base}/${tarball}"; curl -fsSLO "${base}/checksums.txt"; \
    grep " ${tarball}\$" checksums.txt | sha256sum -c -; \
    tar -xzf "${tarball}"; \
    install -m 0755 "$(find . -maxdepth 2 -type f -name lg | head -1)" /usr/local/bin/lg
RUN --mount=type=tmpfs,target=/dl \
    set -eu; cd /dl; \
    tarball="lgx_${LGX_VERSION}_linux_amd64.tar.gz"; \
    base="https://github.com/abogoyavlensky/lgx/releases/download/v${LGX_VERSION}"; \
    curl -fsSLO "${base}/${tarball}"; curl -fsSLO "${base}/checksums.txt"; \
    grep " ${tarball}\$" checksums.txt | sha256sum -c -; \
    tar -xzf "${tarball}"; \
    install -m 0755 "$(find . -maxdepth 2 -type f -name lgx | head -1)" /usr/local/bin/lgx
WORKDIR /src/app
COPY lgx.edn main.lg ./
COPY src/ src/
RUN lgx install && lgx build \
 && test -x bin/attractor \
 && bin/attractor help >/dev/null

# ---------------------------------------------------------------------------
# 2. final: the binary plus what it execs at run time
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
