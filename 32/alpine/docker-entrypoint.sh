#!/bin/sh
set -eu

: "${BITCOIN_DATA:=/home/bitcoin/.bitcoin}"

case "${1:-}" in
  -*)
    set -- bitcoind "$@"
    ;;
esac

if [ "${1:-}" = "bitcoind" ]; then
  mkdir -p "${BITCOIN_DATA}"
  chmod 700 "${BITCOIN_DATA}"
  set -- "$@" -datadir="${BITCOIN_DATA}"
fi

exec "$@"