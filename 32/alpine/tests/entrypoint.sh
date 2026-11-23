#!/bin/sh
set -eu

entrypoint="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)/docker-entrypoint.sh"
tmp="$(mktemp -d)"
trap 'rm -f "$tmp/bin/bitcoind" "$tmp/bin/chmod" "$tmp/output" "$tmp/chmod-called"; rmdir "$tmp/existing" "$tmp/created" "$tmp/bin" "$tmp" 2>/dev/null || true' EXIT
mkdir "$tmp/bin" "$tmp/existing"

cat > "$tmp/bin/bitcoind" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$TEST_OUTPUT"
umask >> "$TEST_OUTPUT"
EOF
cat > "$tmp/bin/chmod" <<'EOF'
#!/bin/sh
touch "$TEST_CHMOD_CALLED"
exit 1
EOF
chmod +x "$tmp/bin/bitcoind" "$tmp/bin/chmod"
export PATH="$tmp/bin:$PATH" TEST_OUTPUT="$tmp/output" TEST_CHMOD_CALLED="$tmp/chmod-called"

for data in "$tmp/existing" "$tmp/created"; do
  BITCOIN_DATA="$data" sh "$entrypoint" -regtest
  test -d "$data"
  printf '%s\n' "-regtest" "-datadir=$data" "0077" | cmp - "$tmp/output"
  test ! -e "$tmp/chmod-called"
done

printf '%s\n' "not started" > "$tmp/output"
if BITCOIN_DATA="$tmp/output/child" sh "$entrypoint" -regtest 2>/dev/null; then
  echo "Entrypoint accepted an unusable data directory" >&2
  exit 1
fi
printf '%s\n' "not started" | cmp - "$tmp/output"

echo "Entrypoint checks passed"
