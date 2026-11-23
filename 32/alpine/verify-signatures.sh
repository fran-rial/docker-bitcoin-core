#!/bin/sh
set -eu
set -f

status_file="$1"
if grep -E '^\[GNUPG:\] (BADSIG|ERRSIG|EXPSIG|EXPKEYSIG|REVKEYSIG|KEYREVOKED|SIGEXPIRED)( |$)' "$status_file" >&2; then
  echo "Rejected invalid or expired GPG signature status" >&2
  exit 1
else
  status="$?"
  if [ "$status" -ne 1 ]; then exit "$status"; fi
fi

valid_fprs="$(awk '$1 == "[GNUPG:]" && $2 == "VALIDSIG" { print toupper($12 ? $12 : $3) }' "$status_file" | sort -u)"
if [ -n "${TRUSTED_BUILDER_FPRS:-}" ]; then
  matched_fprs=""
  matched_count=0
  for fpr in ${TRUSTED_BUILDER_FPRS}; do
    norm_fpr="$(printf '%s' "$fpr" | tr '[:lower:]' '[:upper:]')"
    case "$norm_fpr" in
      *[!0-9A-F]*|'') echo "Invalid trusted builder fingerprint: $fpr" >&2; exit 1 ;;
    esac
    if printf '%s\n' "$valid_fprs" | grep -Fxq "$norm_fpr" &&
       ! printf '%s\n' "$matched_fprs" | grep -Fxq "$norm_fpr"; then
      matched_fprs="${matched_fprs}
${norm_fpr}"
      matched_count=$((matched_count + 1))
    fi
  done
  if [ "$matched_count" -lt 3 ]; then
    echo "At least 3 distinct trusted signers are required; found $matched_count" >&2
    exit 1
  fi
else
  valid_signers="$(printf '%s\n' "$valid_fprs" | sed '/^$/d' | wc -l)"
  if [ "$valid_signers" -lt 5 ]; then
    echo "At least 5 distinct signers are required; found $valid_signers" >&2
    exit 1
  fi
fi
