# syntax=docker/dockerfile:1.7
#
# Production image for the iBuild Dart API.
#
# Two stages: compile to a native AOT binary with the full Dart SDK, then ship
# only that binary on a slim runtime. The SDK layer (~1 GB) never reaches the
# server.
#
# Build from the `server/` directory:
#   docker build -t ibuild-api server/

# Pinned so a deploy is reproducible and the binary is not silently built by a
# different compiler than CI tested with. pubspec allows ^3.9.0; keep this at
# or near the SDK the team develops on and bump it deliberately.
ARG DART_VERSION=3.12

# --------------------------------------------------------------------------
# Stage 1 — compile
# --------------------------------------------------------------------------
FROM dart:${DART_VERSION} AS build

WORKDIR /build

# Resolve dependencies before copying sources so this layer is reused on every
# build that does not touch the manifests.
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

COPY bin/ bin/
COPY lib/ lib/

# `--offline` fails the build if the sources need a package that the manifests
# did not pin, instead of silently reaching out to pub.dev mid-deploy.
RUN dart pub get --offline \
 && dart compile exe bin/server.dart -o /build/ibuild-api

# --------------------------------------------------------------------------
# Stage 2 — runtime
# --------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

# ca-certificates: the API makes outbound HTTPS calls (Eskiz SMS, bank referral
# partners). Without a trust store those fail at request time with a handshake
# error rather than at build time, so the omission is easy to miss until OTP
# delivery breaks in production.
# curl: used by HEALTHCHECK below.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

# Unprivileged: a compromise through the upload handler should not land on root.
RUN useradd --system --uid 10001 --user-group --no-create-home --home-dir /app ibuild

WORKDIR /app

COPY --from=build /build/ibuild-api /app/ibuild-api

# migrations/ on startup; residence photos are uploaded via admin (optional
# bundled files in residences-images/ — created empty in the image).
COPY migrations/ migrations/

# uploads/ holds user-uploaded files and must outlive the container, so it is a
# volume in production. Create it anyway so the app still starts when nothing
# is mounted. private/ is KYC documents, reachable only through the
# authenticated /v1/documents route — never the public static handler.
RUN mkdir -p residences-images uploads/private \
 && chown -R ibuild:ibuild /app \
 && chmod 700 uploads/private

USER ibuild

# BIND_ADDRESS is overridden to 127.0.0.1 by the production compose file, which
# uses host networking. 0.0.0.0 is the right default for bridge networking,
# where the container is itself the isolation boundary.
ENV PORT=4000 \
    BIND_ADDRESS=0.0.0.0

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${PORT}/v1/health" || exit 1

ENTRYPOINT ["/app/ibuild-api"]
