FROM alpine:3.24.4 AS builder

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

ENV BITCOIN_VERSION=32.1
ENV BITCOIN_PREFIX=/opt/bitcoin-32.1

WORKDIR /build

# Pin the upstream builder-key snapshot rather than following a moving branch.
ENV GUIX_SIGS_COMMIT=93aacee89333de43a96e7d128baa84e737c41b0b
RUN set -eux; \
  curl -fsSLo keys.tar.gz "https://github.com/bitcoin-core/guix.sigs/archive/${GUIX_SIGS_COMMIT}.tar.gz"; \
  tar -xzf keys.tar.gz; \
  gpg --batch --import "guix.sigs-${GUIX_SIGS_COMMIT}"/builder-keys/*.gpg; \
  curl -fsSLO "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS"; \
  curl -fsSLO "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS.asc"; \
  curl -fsSLO "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}.tar.gz"; \
  gpg --batch --status-fd 1 --verify SHA256SUMS.asc SHA256SUMS > SHA256SUMS.status; \
  if grep -E '^\[GNUPG:\] (BADSIG|ERRSIG|EXPSIG|EXPKEYSIG|REVKEYSIG|KEYREVOKED|KEYEXPIRED|SIGEXPIRED) ' SHA256SUMS.status >&2; then \
    echo "Release signature verification rejected the status above" >&2; exit 1; \
  else \
    status="$?"; \
    if [ "$status" -ne 1 ]; then exit "$status"; fi; \
  fi; \
  valid_signers="$(awk '$1 == "[GNUPG:]" && $2 == "VALIDSIG" { print $12 ? $12 : $3 }' SHA256SUMS.status | sort -u | wc -l)"; \
  test "$valid_signers" -ge 5; \
  grep " bitcoin-${BITCOIN_VERSION}.tar.gz\$" SHA256SUMS | sha256sum -c -; \
  tar -xzf "bitcoin-${BITCOIN_VERSION}.tar.gz"

WORKDIR /build/bitcoin-32.1

RUN cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${BITCOIN_PREFIX}" \
    -DBUILD_GUI=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_TX=ON \
    -DENABLE_IPC=OFF \
    -DENABLE_WALLET=ON \
    -DWITH_ZMQ=ON \
    -DINSTALL_MAN=OFF \
  && cmake --build build --parallel 2 \
  && cmake --install build

FROM alpine:3.24.4

ARG UID=100
ARG GID=101

RUN addgroup -g "${GID}" -S bitcoin \
  && adduser -u "${UID}" -S -G bitcoin bitcoin \
  && apk add --no-cache libstdc++ shadow sqlite-libs su-exec zeromq

ENV BITCOIN_DATA=/home/bitcoin/.bitcoin
ENV BITCOIN_VERSION=32.1
ENV PATH=/opt/bitcoin-32.1/bin:$PATH

COPY --from=builder /opt/bitcoin-32.1 /opt/bitcoin-32.1
COPY docker-entrypoint.sh /entrypoint.sh

VOLUME ["/home/bitcoin/.bitcoin"]
EXPOSE 8332 8333 18332 18333 18443 18444 38332 38333
ENTRYPOINT ["/entrypoint.sh"]

RUN bitcoind -version | grep "Bitcoin Core daemon version v${BITCOIN_VERSION}"

CMD ["bitcoind"]
