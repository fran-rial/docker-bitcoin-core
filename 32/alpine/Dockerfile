# syntax=docker/dockerfile:1.7

ARG ALPINE_VERSION=3.24.4
ARG BITCOIN_VERSION=32.1
ARG BITCOIN_PREFIX=/opt/bitcoin-32.1
ARG GUIX_SIGS_COMMIT=93aacee89333de43a96e7d128baa84e737c41b0b
ARG BUILD_JOBS=2
ARG USE_DEV_URANDOM=0

FROM alpine:${ALPINE_VERSION} AS builder

ARG BITCOIN_VERSION
ARG BITCOIN_PREFIX
ARG GUIX_SIGS_COMMIT
ARG BUILD_JOBS
ARG USE_DEV_URANDOM

RUN apk add --no-cache \
  boost-dev \
  build-base \
  ca-certificates \
  cmake \
  curl \
  gnupg \
  linux-headers \
  pkgconf \
  python3 \
  sqlite-dev \
  zeromq-dev

WORKDIR /build

# Replace with space/newline-separated primary key fingerprints of trusted builders
ENV TRUSTED_BUILDER_FPRS=""

COPY verify-signatures.sh /usr/local/bin/verify-signatures

# Keep the temporary GPG home in the builder to avoid racing agent socket cleanup.
RUN set -eu; \
  GNUPGHOME="$(mktemp -d)"; \
  export GNUPGHOME; \
  curl -fsSLo keys.tar.gz "https://github.com/bitcoin-core/guix.sigs/archive/${GUIX_SIGS_COMMIT}.tar.gz"; \
  tar -xzf keys.tar.gz "guix.sigs-${GUIX_SIGS_COMMIT}/builder-keys"; \
  gpg --batch --import "guix.sigs-${GUIX_SIGS_COMMIT}/builder-keys"/*.gpg; \
  curl -fsSLO "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS"; \
  curl -fsSLO "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS.asc"; \
  curl -fsSLO "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}.tar.gz"; \
  gpg --batch --status-fd 1 --verify SHA256SUMS.asc SHA256SUMS > SHA256SUMS.status; \
  sh /usr/local/bin/verify-signatures SHA256SUMS.status; \
  grep -E "  bitcoin-${BITCOIN_VERSION}\.tar\.gz$" SHA256SUMS | sha256sum -c -; \
  tar -xzf "bitcoin-${BITCOIN_VERSION}.tar.gz"; \
  rm -rf "$GNUPGHOME" keys.tar.gz "guix.sigs-${GUIX_SIGS_COMMIT}" SHA256SUMS SHA256SUMS.asc SHA256SUMS.status "bitcoin-${BITCOIN_VERSION}.tar.gz"

WORKDIR /build/bitcoin-${BITCOIN_VERSION}

RUN set -eu; \
  case "${USE_DEV_URANDOM}" in \
    0) set -- ;; \
    1) set -- -DHAVE_GETRANDOM=OFF ;; \
    *) echo "USE_DEV_URANDOM must be 0 or 1" >&2; exit 1 ;; \
  esac; \
  cmake -B build "$@" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${BITCOIN_PREFIX}" \
    -DBUILD_GUI=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_TX=ON \
    -DENABLE_IPC=OFF \
    -DENABLE_WALLET=ON \
    -DWITH_ZMQ=ON \
    -DINSTALL_MAN=OFF \
  && cmake --build build --parallel "${BUILD_JOBS}" \
  && cmake --install build \
  && rm -rf /build/bitcoin-${BITCOIN_VERSION}


FROM alpine:${ALPINE_VERSION}

ARG UID=100
ARG GID=101
ARG BITCOIN_VERSION
ARG BITCOIN_PREFIX

ENV BITCOIN_DATA=/home/bitcoin/.bitcoin \
    BITCOIN_VERSION=${BITCOIN_VERSION} \
    PATH=${BITCOIN_PREFIX}/bin:${PATH}

RUN addgroup -g "${GID}" -S bitcoin \
  && adduser -u "${UID}" -S -G bitcoin bitcoin \
  && apk add --no-cache libstdc++ shadow sqlite-libs su-exec zeromq

COPY --from=builder --chown=root:root "${BITCOIN_PREFIX}" "${BITCOIN_PREFIX}"
COPY --chown=root:root docker-entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh

VOLUME ["${BITCOIN_DATA}"]
EXPOSE 8332 8333 18332 18333 18443 18444 38332 38333
ENTRYPOINT ["/entrypoint.sh"]

RUN bitcoind -version | grep -q "Bitcoin Core daemon version v${BITCOIN_VERSION}"

CMD ["bitcoind"]