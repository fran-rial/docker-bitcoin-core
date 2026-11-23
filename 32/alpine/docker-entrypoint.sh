#!/bin/sh
set -eu

: "${BITCOIN_DATA:=/home/bitcoin/.bitcoin}"

case "${1:-}" in
  -*)
    set -- bitcoind "$@"
    ;;
esac

if [ "${1:-}" = "bitcoind" ]; then
  umask 077
  mkdir -p "${BITCOIN_DATA}"
  set -- "$@" -datadir="${BITCOIN_DATA}"
fi

exec "$@"