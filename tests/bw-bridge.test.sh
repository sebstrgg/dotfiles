#!/bin/bash
# Failure mode: an expired or unsafe cache must never reach an agent's CLI.
set -euo pipefail
[[ $(uname -s) == Linux ]] || {
	echo 'SKIP: Linux runtime cache needs tmpfs'
	exit 0
}
root=$(cd "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d /dev/shm/bw-bridge-test.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
export XDG_RUNTIME_DIR=$fixture
cache=$root/bin/bw-session-cache
printf 'fixture-session\n' | "$cache" store "$(($(date +%s) + 60))"
[[ $("$cache" read) == fixture-session ]]
[[ $(stat -c %a "$fixture/bw-bridge/session") == 600 ]]
chmod 644 "$fixture/bw-bridge/session"
if "$cache" read >/dev/null 2>&1; then exit 1; fi
chmod 600 "$fixture/bw-bridge/session"
printf 'fixture-session\n' | "$cache" store 1
if "$cache" read >/dev/null 2>&1; then exit 1; fi
[[ ! -e $fixture/bw-bridge/session ]]
echo 'PASS: expired and readable-by-others sessions are refused'
mkdir "$fixture/stubs"
cat >"$fixture/stubs/npx" <<'STUB'
#!/bin/bash
[[ ${BW_SESSION:-} == fixture-session ]] && echo '{"status":"unlocked"}' || echo '{"status":"locked"}'
STUB
chmod +x "$fixture/stubs/npx"
export PATH="$fixture/stubs:$PATH"
[[ $("$root/bin/bw-vault" status | jq -r .status) == locked ]]
printf 'fixture-session\n' | "$cache" store "$(($(date +%s) + 60))"
[[ $("$root/bin/bw-vault" status | jq -r .status) == unlocked ]]
printf 'fixture-session\n' | "$cache" store 1
[[ $("$root/bin/bw-vault" status | jq -r .status) == locked ]]
printf 'fixture-session\n' | "$cache" store "$(($(date +%s) + 60))"
[[ $("$root/bin/security" find-generic-password -a "$(id -un)" -s personal-infra-bitwarden-session -w) == fixture-session ]]
if "$root/bin/security" find-generic-password -a other-user -s personal-infra-bitwarden-session -w >/dev/null 2>&1; then exit 1; fi
"$root/bin/security" delete-generic-password -a "$(id -un)" -s personal-infra-bitwarden-session
[[ $("$root/bin/bw-vault" status | jq -r .status) == locked ]]
echo 'PASS: CLI and infrastructure compatibility share the expiring cache'
printf 'fixture-session\n' | "$cache" store "$(($(date +%s) + 3600))"
cat >"$fixture/stubs/npx" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"${XDG_RUNTIME_DIR}/npx.log"
echo '{"status":"locked"}'
STUB
"$root/bin/bw-bridge" expire >/dev/null
[[ ! -e $fixture/bw-bridge/session ]]
grep -q 'lock' "$fixture/npx.log"
echo 'PASS: a firing expiry timer closes an unexpired bridge'
ln -s "$fixture/stubs/npx" "$fixture/bw-bridge/session"
if "$cache" read >/dev/null 2>&1; then exit 1; fi
chmod 755 "$fixture"
if "$cache" read >/dev/null 2>&1; then exit 1; fi
echo 'PASS: symlink cache and unsafe runtime directory are refused'
