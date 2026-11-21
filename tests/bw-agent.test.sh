#!/bin/bash
# Failure modes: an agent must unlock its own identity without a human, never
# borrow the owner's bridge session, never serve a cached item the server no
# longer grants, and survive rotation, parallel callers and planted links.
set -euo pipefail
[[ $(uname -s) == Linux ]] || {
	echo 'SKIP: Linux secret store and runtime cache'
	exit 0
}
root=$(cd "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d /dev/shm/bw-agent-test.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
export XDG_RUNTIME_DIR=$fixture/run XDG_STATE_HOME=$fixture/state XDG_CONFIG_HOME=$fixture/config
mkdir -m 700 "$XDG_RUNTIME_DIR" "$fixture/stubs" "$fixture/server"
export LOG=$fixture/calls.log SERVER=$fixture/server
profile=$XDG_RUNTIME_DIR/bw-agent/cli
session=$XDG_RUNTIME_DIR/bw-agent/session

# systemd-creds stand-in: a plain copy, enough to exercise the store path.
cat >"$fixture/stubs/systemd-creds" <<'STUB'
#!/bin/bash
[[ $1 == --user ]] && shift
case $1 in
encrypt) cat >"$4" ;;
decrypt) cat "$3" ;;
esac
STUB
# Bitwarden CLI stand-in. The server holds the valid API secret and the items
# the identity is granted; sync copies them into the local profile.
cat >"$fixture/stubs/npx" <<'STUB'
#!/bin/bash
shift 4 # --yes --package=... -- bw
p=$BITWARDENCLI_APPDATA_DIR
mkdir -p "$p"
echo "$1 session=${BW_SESSION:-}" | tee -a "$LOG.all" >>"$LOG"
current() { [[ -n ${BW_SESSION:-} && -f $p/session && $BW_SESSION == $(<"$p/session") ]]; }
case $1 in
status)
	if [[ ! -f $p/auth ]]; then echo '{"status":"unauthenticated"}'
	elif current; then echo '{"status":"unlocked"}'
	else echo '{"status":"locked"}'; fi ;;
config) ;;
login) [[ $BW_CLIENTSECRET == $(<"$SERVER/secret") ]] && printf '%s' "$BW_CLIENTSECRET" >"$p/auth" ;;
unlock) [[ -f $p/auth && $BW_PASSWORD == fixture-password ]] && echo "s$RANDOM" >"$p/session" && printf '%s' "$(<"$p/session")" ;;
sync)
	[[ ! -e $SERVER/offline && $(<"$p/auth") == $(<"$SERVER/secret") ]] || exit 1
	# Like the real CLI, a sync without --force may skip and keep the cache.
	[[ ${2:-} == --force ]] && cp "$SERVER/items" "$p/items"
	true ;;
get)
	current || exit 1
	if [[ -s $p/items ]]; then cat "$p/items"; else echo '{"success":false,"message":"Not found."}'; exit 1; fi ;;
encode) base64 -w0 ;;
create) current && echo created ;;
edit) current && if [[ -n ${4:-} ]]; then echo "edited:$(base64 -d <<<"$4")"; else echo "edited:$(base64 -d)"; fi ;;
esac
STUB
chmod +x "$fixture/stubs/"*
export PATH="$fixture/stubs:$PATH"
agent=$root/bin/bw-agent
identity() { printf '{"server":"https://vault.example","client_id":"user.x","client_secret":"%s","password":"fixture-password"}' "$1"; }
unlocks() { grep -c '^unlock' "$LOG" || true; }
printf 'fixture-value\n' >"$SERVER/items"
printf secret-1 >"$SERVER/secret"

if "$agent" get password some-id >/dev/null 2>&1; then exit 1; fi
echo 'PASS: no stored identity fails closed'

printf 'owner-session\n' | "$root/bin/bw-session-cache" store "$(($(date +%s) + 60))"
owner=$(cat "$XDG_RUNTIME_DIR/bw-bridge/session")
identity secret-1 | "$agent" provision >/dev/null
[[ $("$agent" get password some-id) == fixture-value ]]
[[ $(stat -c %a "$session") == 600 && -f $profile/auth && ! -e $XDG_STATE_HOME/bw-agent/cli ]]
echo 'PASS: provisioned identity unlocks unattended into a volatile profile'

: >"$LOG"
"$agent" get password some-id >/dev/null
[[ $(unlocks) == 0 ]]
echo 'PASS: a valid session is reused without another unlock'

rm "$profile/session"
: >"$LOG"
for _ in 1 2 3 4; do "$agent" get password some-id >"$fixture/out.$_" & done
wait
[[ $(unlocks) == 1 && $(cat "$fixture"/out.* | sort -u) == fixture-value ]]
echo 'PASS: parallel callers share one unlock'

# edit starts first and get last: a payload command that took the lock before
# reading its input would hold it while its producer waits for it.
# shellcheck disable=SC2016
piped='{ sleep 1; "$1" get password some-id; } | { sleep 0.5; "$1" encode; } | "$1" edit item some-id'
[[ $(timeout 20 bash -c "$piped" _ "$agent") == edited:fixture-value ]]
echo 'PASS: a piped get, encode and edit do not deadlock on the lock'

payload=$(printf fixture-value | base64 -w0)
[[ $(timeout 10 "$agent" edit item some-id "$payload" < <(sleep 30)) == edited:fixture-value ]]
timeout 10 "$agent" create attachment --file x --itemid y < <(sleep 30) >/dev/null
echo 'PASS: a payload in argv, or an attachment, never waits on an open stdin'

# shellcheck disable=SC2016
piped='{ sleep 1; "$1" get password some-id; } | { sleep 0.5; "$1" encode; } | "$1" edit item some-id ""'
[[ $(timeout 20 bash -c "$piped" _ "$agent") == edited:fixture-value ]]
echo 'PASS: an empty payload argument reads stdin before the lock'

: >"$SERVER/items"
if out=$("$agent" get password some-id); then exit 1; fi
[[ $(wc -l <<<"$out") == 1 && $out != *fixture-value* ]]
printf 'fixture-value\n' >"$SERVER/items"
echo 'PASS: a grant revoked on the server stops the cached item, with one error document'

touch "$SERVER/offline"
if "$agent" get password some-id >/dev/null 2>&1; then exit 1; fi
rm "$SERVER/offline"
echo 'PASS: an unreachable server fails closed'

printf secret-2 >"$SERVER/secret"
if "$agent" get password some-id >/dev/null 2>&1; then exit 1; fi
identity secret-2 | "$agent" provision >/dev/null
[[ $("$agent" get password some-id) == fixture-value ]]
if identity secret-3 | "$agent" provision >/dev/null 2>&1; then exit 1; fi
[[ $("$agent" get password some-id) == fixture-value ]]
echo 'PASS: a rotated key re-provisions into a fresh profile; a bad one keeps the stored identity'

rm "$session"
ln -s "$XDG_RUNTIME_DIR/bw-bridge/session" "$session"
rm "$profile/session"
[[ $("$agent" get password some-id) == fixture-value ]]
[[ ! -L $session && $(cat "$XDG_RUNTIME_DIR/bw-bridge/session") == "$owner" ]]
echo 'PASS: a planted session link is replaced, never written through'

if echo '{"server":"x"}' | "$agent" provision >/dev/null 2>&1; then exit 1; fi
if identity secret-2 | sed 's/https/http/' | "$agent" provision >/dev/null 2>&1; then exit 1; fi
"$agent" forget >/dev/null
[[ ! -e $XDG_CONFIG_HOME/bw-agent/credentials.cred && ! -e $session && ! -e $profile ]]
echo 'PASS: malformed or plain-http identity is refused and forget removes host state'

if grep -q "session=owner-session" "$LOG.all"; then exit 1; fi
echo 'PASS: no command ever saw the owner session'
