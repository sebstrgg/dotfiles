#!/bin/bash
# Failure modes: an agent must unlock its own identity without a human, never
# borrow the owner's bridge session, and re-unlock when its session goes stale.
set -euo pipefail
[[ $(uname -s) == Linux ]] || {
	echo 'SKIP: Linux secret store and runtime cache'
	exit 0
}
root=$(cd "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d /dev/shm/bw-agent-test.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
export XDG_RUNTIME_DIR=$fixture/run XDG_STATE_HOME=$fixture/state XDG_CONFIG_HOME=$fixture/config
mkdir -m 700 "$XDG_RUNTIME_DIR" "$fixture/stubs"
log=$fixture/calls.log

# systemd-creds stand-in: a plain copy, enough to exercise the store path.
cat >"$fixture/stubs/systemd-creds" <<'STUB'
#!/bin/bash
[[ $1 == --user ]] && shift
case $1 in
encrypt) cat >"$4" ;;
decrypt) cat "$3" ;;
esac
STUB
# Bitwarden CLI stand-in: one identity whose session is "agent-session".
cat >"$fixture/stubs/npx" <<'STUB'
#!/bin/bash
shift 4 # --yes --package=... -- bw
state=$BITWARDENCLI_APPDATA_DIR/fake
mkdir -p "$BITWARDENCLI_APPDATA_DIR"
echo "$1 session=${BW_SESSION:-}" >>"$LOG"
case $1 in
status)
	if [[ ! -f $state ]]; then echo '{"status":"unauthenticated"}'
	elif [[ ${BW_SESSION:-} == agent-session && $(<"$state") == unlocked ]]; then echo '{"status":"unlocked"}'
	else echo '{"status":"locked"}'; fi ;;
config) ;;
login) [[ $BW_CLIENTSECRET == fixture-secret ]] && echo locked >"$state" ;;
unlock) [[ $BW_PASSWORD == fixture-password ]] && echo unlocked >"$state" && printf agent-session ;;
sync) ;;
get) [[ ${BW_SESSION:-} == agent-session ]] && echo fixture-value ;;
lock) echo locked >"$state" ;;
esac
STUB
chmod +x "$fixture/stubs/"*
export PATH="$fixture/stubs:$PATH" LOG=$log
agent=$root/bin/bw-agent

if "$agent" get password some-id >/dev/null 2>&1; then exit 1; fi
echo 'PASS: no stored identity fails closed'

printf 'owner-session\n' | "$root/bin/bw-session-cache" store "$(($(date +%s) + 60))"
echo '{"server":"https://vault.example","client_id":"user.x","client_secret":"fixture-secret","password":"fixture-password"}' |
	"$agent" provision >/dev/null
[[ $("$agent" get password some-id) == fixture-value ]]
if grep -q 'session=owner-session' "$log"; then exit 1; fi
[[ $(stat -c %a "$XDG_RUNTIME_DIR/bw-agent/session") == 600 ]]
echo 'PASS: provisioned identity unlocks unattended and never sees the owner session'

: >"$log"
"$agent" get password some-id >/dev/null
if grep -q '^unlock' "$log"; then exit 1; fi
echo 'PASS: a valid session is reused without another unlock'

echo locked >"$XDG_STATE_HOME/bw-agent/cli/fake"
: >"$log"
[[ $("$agent" get password some-id) == fixture-value ]]
grep -q '^unlock' "$log"
echo 'PASS: a locked session re-unlocks from the host store'

if echo '{"server":"x"}' | "$agent" provision >/dev/null 2>&1; then exit 1; fi
"$agent" forget >/dev/null
[[ ! -e $XDG_CONFIG_HOME/bw-agent/credentials.cred && ! -e $XDG_RUNTIME_DIR/bw-agent/session ]]
echo 'PASS: malformed identity is refused and forget removes host state'
