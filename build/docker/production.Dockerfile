# syntax=docker/dockerfile:1

# for production releases (`ferret` image)

# While we already know commit and version from commit.txt and version.txt inside image,
# it is not possible to use them in LABELs for the final image.
# We need to pass them as build arguments.
# Defining ARGs there makes them global.
ARG LABEL_VERSION
ARG LABEL_COMMIT


# build stage

FROM ghcr.io/ferretdb/golang:1.21.5-1 AS production-build

ARG TARGETARCH
ARG TARGETVARIANT

ARG LABEL_VERSION
ARG LABEL_COMMIT
RUN test -n "$LABEL_VERSION"
RUN test -n "$LABEL_COMMIT"

# use a single directory for all Go caches to simpliy RUN --mount commands below
ENV GOPATH /cache/gopath
ENV GOCACHE /cache/gocache
ENV GOMODCACHE /cache/gomodcache

# remove ",direct"
ENV GOPROXY https://proxy.golang.org

# do not raise it without providing a separate v1 build
# because v2+ is problematic for some virtualization platforms and older hardware
ENV GOAMD64=v1

# GOARM is set in the script below

ENV CGO_ENABLED=0

# see .dockerignore
WORKDIR /src
COPY . .

RUN --mount=type=cache,target=/cache <<EOF
set -ex

# copy cached stdlib builds from base image
flock --verbose /cache/ cp -Rn /root/.cache/go-build/. /cache/gocache

# TODO https://github.com/FerretDB/FerretDB/issues/2170
# That command could be run only once by using a separate stage;
# see https://www.docker.com/blog/faster-multi-platform-builds-dockerfile-cross-compilation-guide/
flock --verbose /cache/ go mod download

git status

# Set GOARM explicitly due to https://github.com/docker-library/golang/issues/494.
export GOARM=${TARGETVARIANT#v}

# Do not trim paths to reuse build cache.

# check that stdlib was cached
go install -v std

go build -v -o=bin/ferretdb ./cmd/ferretdb

go version -m bin/ferretdb
bin/ferretdb --version
EOF


# stage for binary only

FROM scratch AS production-binary

COPY --from=production-build /src/bin/ferretdb /ferretdb


# final stage

FROM debian:bookworm AS production

# Create the ferretdb group (GID 1000)
RUN groupadd -g 1000 ferretdb

# Create the ferretdb user (UID 1000) and assign it to group 1000
RUN useradd -ms /bin/bash -u 1000 -g ferretdb ferretdb

# Create /state directory and set ownership to UID 1000, GID 0
RUN mkdir -p /state \
    && chown -R 1000:0 /state \
    && chmod -R g=u /state  # Allows OpenShift's arbitrary UID to write

# Set the working directory
WORKDIR /state

# Copy binary
COPY --from=production-build /src/bin/ferretdb /ferretdb

# Expose necessary ports
EXPOSE 27017 27018 8080

# Run as ferretdb user but with GID 0 for OpenShift compatibility
USER 1000:0

# Set entrypoint
ENTRYPOINT ["/ferretdb"]

# don't forget to update documentation if you change defaults
ENV FERRETDB_LISTEN_ADDR=:27017
# ENV FERRETDB_LISTEN_TLS=:27018
ENV FERRETDB_DEBUG_ADDR=:8080
ENV FERRETDB_STATE_DIR=/state
ENV FERRETDB_SQLITE_URL=file:/state/

ARG LABEL_VERSION
ARG LABEL_COMMIT

# TODO https://github.com/FerretDB/FerretDB/issues/2212
LABEL org.opencontainers.image.description="A truly Open Source MongoDB alternative"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.revision="${LABEL_COMMIT}"
LABEL org.opencontainers.image.source="https://github.com/FerretDB/FerretDB"
LABEL org.opencontainers.image.title="FerretDB"
LABEL org.opencontainers.image.url="https://www.ferretdb.com/"
LABEL org.opencontainers.image.vendor="FerretDB Inc."
LABEL org.opencontainers.image.version="${LABEL_VERSION}"
