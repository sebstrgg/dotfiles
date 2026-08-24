#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

mkdir -p "$TMP/bin"
cat >"$TMP/bin/npx" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" >"$BW_VAULT_TEST_ARGS"
EOF
chmod 700 "$TMP/bin/npx"

export BW_VAULT_TEST_ARGS="$TMP/args"
PATH="$TMP/bin:$PATH" "$ROOT/bin/bw-vault" status >/dev/null

cat >"$TMP/expected" <<'EOF'
--yes
--package=@bitwarden/cli@2026.6.0
--
bw
status
EOF

cmp "$TMP/expected" "$TMP/args"
printf 'PASS: bw-vault pins the Vaultwarden-compatible CLI\n'
