#!/bin/sh
set -eu

: "${BITCOIN_DATA:=/home/bitcoin/.bitcoin}"

if [ -n "${GID:-}" ] && [ "${GID}" != "0" ] && [ "$(id -g bitcoin)" != "${GID}" ]; then
  groupmod -g "${GID}" bitcoin
fi

if [ -n "${UID:-}" ] && [ "${UID}" != "0" ] && [ "$(id -u bitcoin)" != "${UID}" ]; then
  usermod -u "${UID}" bitcoin
fi

echo "$0: assuming uid:gid for bitcoin:bitcoin of $(id -u bitcoin):$(id -g bitcoin)"

case "${1:-}" in
  -*)
    echo "$0: assuming arguments for bitcoind"
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
    echo "$0: unable to determine bitcoin home directory" >&2
    exit 1
  fi

  echo "$0: starting recursive ownership change for ${home_dir}"
  chown -R bitcoin:bitcoin "${home_dir}"
  echo "$0: finished recursive ownership change for ${home_dir}"
  echo "$0: starting recursive ownership change for ${BITCOIN_DATA}"
  chown -R bitcoin:bitcoin "${BITCOIN_DATA}"
  echo "$0: finished recursive ownership change for ${BITCOIN_DATA}"
  echo "$0: setting data directory to ${BITCOIN_DATA}"

  set -- "$@" \
    -datadir="${BITCOIN_DATA}" \
    -daemon=0 \
    -printtoconsole
fi

case "${1:-}" in
  bitcoind|bitcoin-cli|bitcoin-tx)
    echo
    exec su-exec bitcoin "$@"
    ;;
esac

echo
exec "$@"
