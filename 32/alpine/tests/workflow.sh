#!/bin/bash
set -euo pipefail

root="$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)"
cd "$root"
tmp="$(mktemp -d)"
trap 'rm -f "$tmp/prepare" "$tmp/build" "$tmp/docker" "$tmp/args" "$tmp/output"; rmdir "$tmp"' EXIT

awk '
  /id: prepare/ { prepare=1 }
  prepare && /^        run: \|/ { script=1; next }
  script && /^      - name:/ { exit }
  script { sub(/^          /, ""); print }
' .github/workflows/build.yaml > "$tmp/prepare"
test -s "$tmp/prepare"

check() {
  local matrix="$1" ref="$2" event="$3" expected="$4"
  : > "$tmp/output"
  MATRIX_VERSION="$matrix" GITHUB_REF="$ref" GITHUB_EVENT_NAME="$event" \
    GITHUB_REPOSITORY="owner/repo" GITHUB_OUTPUT="$tmp/output" \
    bash "$tmp/prepare"
  grep -Fx "$expected" "$tmp/output" >/dev/null
}

for tag in 32.1 32.1-alpine 32.1-alpine-synology; do
  check 32/alpine-synology "refs/tags/$tag" push "tag_suffixes=32.1-alpine-synology"
  grep -Fx 'use_dev_urandom=1' "$tmp/output" >/dev/null
  grep -Fx 'build_context=32/alpine' "$tmp/output" >/dev/null
  grep -Fx 'push=true' "$tmp/output" >/dev/null
done
check 32/alpine-synology refs/tags/32.2 push 'build=false'
check 32/alpine-synology refs/heads/main push 'tag_suffixes=32-alpine-synology'
grep -Fx 'push=true' "$tmp/output" >/dev/null
check 32/alpine-synology refs/pull/1/merge pull_request 'push=false'
check 32/alpine refs/tags/32.1-alpine-synology push 'build=false'
check 32 refs/tags/32.1-alpine-synology push 'build=false'
check 32/alpine refs/tags/32.1 push 'tag_suffixes=32.1-alpine'
grep -Fx 'use_dev_urandom=0' "$tmp/output" >/dev/null
check 32/alpine refs/heads/main push 'tag_suffixes=32-alpine alpine'

awk '
  /name: Build Docker image/ { build=1 }
  build && /^        run: \|/ { script=1; next }
  script {
    sub(/^          /, "")
    gsub(/\$\{\{ steps\.prepare\.outputs\.build_date \}\}/, "test-date")
    gsub(/\$\{\{ steps\.prepare\.outputs\.platforms \}\}/, "linux/amd64")
    gsub(/\$\{\{ steps\.final_tags\.outputs\.effective_push \}\}/, "false")
    print
  }
' .github/workflows/build.yaml > "$tmp/build"
cat > "$tmp/docker" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$TEST_DOCKER_ARGS"
EOF
chmod +x "$tmp/docker"
for mode in 0 1; do
  PATH="$tmp:$PATH" TEST_DOCKER_ARGS="$tmp/args" \
    RAW_TAGS="example:tag" BUILD_CONTEXT="32/alpine" USE_DEV_URANDOM="$mode" \
    GITHUB_SHA=12345678 bash "$tmp/build"
  grep -Fx "USE_DEV_URANDOM=$mode" "$tmp/args" >/dev/null
  grep -Fx "32/alpine/" "$tmp/args" >/dev/null
done

echo "Workflow metadata checks passed"
