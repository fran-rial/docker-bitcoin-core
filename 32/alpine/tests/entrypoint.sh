#!/bin/sh
set -eu

entrypoint="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)/docker-entrypoint.sh"
tmp="$(mktemp -d)"
trap 'rm -f "$tmp/bin/bitcoind" "$tmp/bin/bitcoin-cli" "$tmp/bin/chmod" "$tmp/bin/chown" "$tmp/bin/getent" "$tmp/bin/id" "$tmp/bin/su-exec" "$tmp/bin/groupmod" "$tmp/bin/usermod" "$tmp/output" "$tmp/stdout" "$tmp/log"; rmdir "$tmp/existing" "$tmp/created" "$tmp/bin" "$tmp" 2>/dev/null || true' EXIT
mkdir "$tmp/bin" "$tmp/existing"

cat > "$tmp/bin/bitcoind" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$TEST_OUTPUT"
umask >> "$TEST_OUTPUT"
EOF
cat > "$tmp/bin/bitcoin-cli" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$tmp/bin/chmod" <<'EOF'
#!/bin/sh
printf 'chmod %s\n' "$*" >> "$TEST_LOG"
test "${TEST_FAIL_CHMOD:-0}" != 1
EOF
cat > "$tmp/bin/chown" <<'EOF'
#!/bin/sh
printf 'chown %s\n' "$*" >> "$TEST_LOG"
EOF
cat > "$tmp/bin/getent" <<'EOF'
#!/bin/sh
printf 'bitcoin:x:100:101::%s:/bin/false\n' "$TEST_HOME"
EOF
cat > "$tmp/bin/id" <<'EOF'
#!/bin/sh
case "$1" in
  -u) echo "$TEST_ID_UID" ;;
  -g) echo 101 ;;
  *) exit 1 ;;
esac
EOF
cat > "$tmp/bin/su-exec" <<'EOF'
#!/bin/sh
test "$1" = bitcoin
shift
exec "$@"
EOF
cat > "$tmp/bin/groupmod" <<'EOF'
#!/bin/sh
printf 'groupmod %s\n' "$*" >> "$TEST_LOG"
EOF
cat > "$tmp/bin/usermod" <<'EOF'
#!/bin/sh
printf 'usermod %s\n' "$*" >> "$TEST_LOG"
EOF
chmod +x "$tmp/bin/"*
TEST_ID_UID="$(sh -c 'printf "%s" "${UID:-100}"')"
export PATH="$tmp/bin:$PATH" TEST_OUTPUT="$tmp/output" TEST_LOG="$tmp/log" TEST_HOME="$tmp" TEST_ID_UID

for data in "$tmp/existing" "$tmp/created"; do
  : > "$tmp/log"
  BITCOIN_DATA="$data" sh "$entrypoint" -regtest > "$tmp/stdout"
  test -d "$data"
  printf '%s\n' "-regtest" "-datadir=$data" "-daemon=0" "-printtoconsole" "0077" | cmp - "$tmp/output"
  printf '%s\n' "chmod 700 $data" "chown -R bitcoin:bitcoin $tmp" "chown -R bitcoin:bitcoin $data" | cmp - "$tmp/log"
  printf '%s\n' \
    "$entrypoint: assuming uid:gid for bitcoin:bitcoin of $TEST_ID_UID:101" \
    "$entrypoint: assuming arguments for bitcoind" \
    "$entrypoint: starting recursive ownership change for $tmp" \
    "$entrypoint: finished recursive ownership change for $tmp" \
    "$entrypoint: starting recursive ownership change for $data" \
    "$entrypoint: finished recursive ownership change for $data" \
    "$entrypoint: setting data directory to $data" \
    "" | cmp - "$tmp/stdout"
done

: > "$tmp/log"
env UID=102 GID=103 BITCOIN_DATA="$tmp/existing" sh "$entrypoint" bitcoin-cli -version
if [ "$(env UID=102 sh -c 'printf "%s" "$UID"')" = 102 ]; then
  printf '%s\n' "groupmod -g 103 bitcoin" "usermod -u 102 bitcoin" | cmp - "$tmp/log"
else
  printf '%s\n' "groupmod -g 103 bitcoin" | cmp - "$tmp/log"
fi

printf '%s\n' "not started" > "$tmp/output"
if TEST_FAIL_CHMOD=1 BITCOIN_DATA="$tmp/existing" sh "$entrypoint" -regtest 2>/dev/null; then
  echo "Entrypoint ignored a permission error" >&2
  exit 1
fi
printf '%s\n' "not started" | cmp - "$tmp/output"

echo "Entrypoint checks passed"
