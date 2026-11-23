#!/bin/sh
set -eu

verify="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)/verify-signatures.sh"
status="$(mktemp)"
trap 'rm -f "$status"' EXIT

for fpr in AA BB CC DD; do
  printf '[GNUPG:] VALIDSIG %s 1 2 3 4 5 6 7 8 %s\n' "$fpr" "$fpr" >> "$status"
done
printf '[GNUPG:] VALIDSIG FF 1 2 3 4 5 6 7 8 AA\n' >> "$status"
if TRUSTED_BUILDER_FPRS="" sh "$verify" "$status" 2>/dev/null; then
  echo "Multiple subkeys incorrectly satisfied the default threshold" >&2
  exit 1
fi

printf '[GNUPG:] VALIDSIG EE 1 2 3 4 5 6 7 8 EE\n' >> "$status"
printf '[GNUPG:] KEYEXPIRED 123\n' >> "$status"
TRUSTED_BUILDER_FPRS="" sh "$verify" "$status"
TRUSTED_BUILDER_FPRS="aa AA bb BB cc" sh "$verify" "$status"

if TRUSTED_BUILDER_FPRS="aa AA aA" sh "$verify" "$status" 2>/dev/null; then
  echo "Duplicate fingerprints incorrectly satisfied the trusted threshold" >&2
  exit 1
fi

printf '[GNUPG:] BADSIG invalid\n' >> "$status"
if TRUSTED_BUILDER_FPRS="" sh "$verify" "$status" 2>/dev/null; then
  echo "A bad signature was incorrectly accepted" >&2
  exit 1
fi

echo "Signature checks passed"
