#!/bin/sh
set -eu

: "${BITCOIN_DATA:=/home/bitcoin/.bitcoin}"

if [ -n "${GID:-}" ] && [ "${GID}" != "0" ] && [ "$(id -g bitcoin)" != "${GID}" ]; then
  groupmod -g "${GID}" bitcoin
fi

if [ -n "${UID:-}" ] && [ "${UID}" != "0" ] && [ "$(id -u bitcoin)" != "${UID}" ]; then
  usermod -u "${UID}" bitcoin
fi

case "${1:-}" in
  -*)
    set -- bitcoind "$@"
    ;;
esac

if [ "${1:-}" = "bitcoind" ]; then
  umask 077
  mkdir -p "${BITCOIN_DATA}"
  chmod 700 "${BITCOIN_DATA}"
  home_entry="$(getent passwd bitcoin)"
  home_dir="$(printf '%s\n' "${home_entry}" | cut -d: -f6)"
  if [ -z "${home_dir}" ]; then
    echo "Unable to determine bitcoin home directory" >&2
    exit 1
  fi
  chown bitcoin:bitcoin "${home_dir}"
  chown bitcoin:bitcoin "${BITCOIN_DATA}"
  set -- "$@" -datadir="${BITCOIN_DATA}"
fi

case "${1:-}" in
  bitcoind|bitcoin-cli|bitcoin-tx)
    exec su-exec bitcoin "$@"
    ;;
esac

exec "$@"