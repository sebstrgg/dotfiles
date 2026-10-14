#!/usr/bin/env bash
set -euo pipefail

script=$(cd "$(dirname "$0")/.." && pwd)/bin/dev-disk-trim
workspace=$(mktemp -d)
tmp_fixture=$(mktemp -d /private/tmp/dev-disk-trim-test.XXXXXX)
trap 'rm -rf "$workspace" "$tmp_fixture"' EXIT
mkdir -p "$workspace/stubs"
cat >"$workspace/stubs/stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
tool=${0##*/}
case "$tool" in
df)
	use=${TEST_USE:-66}
	if [[ -e $HOME/cache-trimmed && ${TEST_EARLY:-0} == 1 ]]; then use=55; fi
	printf 'Filesystem blocks used available capacity mounted\n'
	printf '/dev/test 100000 %s %s 99%% /Data\n' "$((use * 1000))" "$(((100 - use) * 1000))"
	;;
pgrep)
	if [[ -n ${TEST_BUSY_COMMAND:-} ]]; then
		[[ $TEST_BUSY_COMMAND =~ ${*: -1} ]] && exit 0
		exit 1
	fi
	exit "${TEST_BUSY_STATUS:-1}"
	;;
lsof)
	# Keep every real tmp directory except the fixture owned by this test.
	printf 'p1\nn/private/tmp\n'
	for dir in /private/tmp/* /private/tmp/.[!.]* /private/tmp/..?*; do
		[[ -d $dir && $dir != "${TEST_TMP:-}" ]] && printf 'n%s\n' "$dir"
	done
	case ${TEST_LSOF:-idle} in
	used) printf 'n%s/open-file\n' "$TEST_TMP" ;;
	used-alias) printf 'n%s/open-file\n' "${TEST_TMP/#\/private\/tmp/\/tmp}" ;;
	error) exit 2 ;;
	esac
	;;
du)
	path=${*: -1}
	case "$path" in
	*/target) printf '7340032\t%s\n' "$path" ;;
	*/.npm) printf '2097152\t%s\n' "$path" ;;
	*) printf '1\t%s\n' "$path" ;;
	esac
	;;
docker)
	if [[ ${1:-} == info ]]; then
		[[ ${TEST_DOCKER_HANG:-0} == 1 ]] && exec sleep 30
		exit "${TEST_DOCKER_STATUS:-0}"
	fi
	printf '%s\n' "$*" >>"$HOME/docker-calls"
	;;
uv | npm | pnpm)
	printf '%s %s\n' "$tool" "$*" >>"$HOME/cache-calls"
	touch "$HOME/cache-trimmed"
	;;
esac
STUB
chmod +x "$workspace/stubs/stub"
for tool in df pgrep lsof docker uv npm pnpm du; do
	ln -s stub "$workspace/stubs/$tool"
done

export PATH="$workspace/stubs:$PATH"

new_home() {
	HOME="$workspace/$1"
	export HOME
	mkdir -p "$HOME/.cache/project/target" "$HOME/.npm"
	unset TEST_USE TEST_BUSY_STATUS TEST_BUSY_COMMAND TEST_EARLY TEST_DOCKER_STATUS TEST_DOCKER_HANG TEST_LSOF TEST_TMP
}

new_home below
export TEST_USE=58
bash "$script" >"$HOME/output"
[[ -d $HOME/.cache/project/target && ! -e $HOME/cache-calls && ! -e $HOME/docker-calls ]]
[[ $(wc -l <"$HOME/output") -eq 1 ]]
printf 'PASS: below threshold leaves data and caches alone\n'

new_home busy
export TEST_BUSY_STATUS=0
bash "$script" >"$HOME/output"
[[ -d $HOME/.cache/project/target && -e $HOME/cache-calls ]]
printf 'PASS: cargo build keeps target while caches are trimmed\n'

new_home idle
bash "$script" >"$HOME/output"
[[ ! -e $HOME/.cache/project/target ]]
printf 'PASS: idle target over 6 GiB is removed\n'

new_home docker-down
export TEST_DOCKER_STATUS=1
bash "$script" >"$HOME/output"
[[ ! -e $HOME/docker-calls ]]
jq -e 'select(.action == "docker" and .status == "unavailable")' "$HOME/output" >/dev/null
printf 'PASS: unavailable Docker daemon skips pruning without failure\n'

for mode in used used-alias error idle; do
	new_home "tmp-$mode"
	export TEST_TMP="$tmp_fixture" TEST_LSOF="$mode"
	touch -t 202001010000 "$tmp_fixture"
	bash "$script" >"$HOME/output"
	if [[ $mode == idle ]]; then
		[[ ! -e $tmp_fixture ]]
	else
		[[ -d $tmp_fixture ]]
	fi
	printf 'PASS: temp directory with lsof %s handled safely\n' "$mode"
done

new_home early
export TEST_BUSY_STATUS=0 TEST_EARLY=1
bash "$script" >"$HOME/output"
[[ -d $HOME/.cache/project/target && ! -e $HOME/docker-calls ]]
[[ $(wc -l <"$HOME/cache-calls") -eq 1 ]]
jq -e 'select(.action == "final" and .target == "66.00% -> 55.00%")' "$HOME/output" >/dev/null
printf 'PASS: stops immediately when cache trimming reaches 55 percent\n'

new_home browsers
mkdir -p "$HOME/Library/Caches/ms-playwright/"{chromium-9,chromium-100,firefox-2,firefox-8,chromium_headless_shell-1,chromium_headless_shell-2,unknown}
bash "$script" >"$HOME/output"
for family in chromium-100 firefox-8 chromium_headless_shell-2 unknown; do
	[[ -d $HOME/Library/Caches/ms-playwright/$family ]]
done
for family in chromium-9 firefox-2 chromium_headless_shell-1; do
	[[ ! -e $HOME/Library/Caches/ms-playwright/$family ]]
done
printf 'PASS: keeps newest numeric revision per browser family\n'

new_home inspection-error
export TEST_BUSY_STATUS=2
bash "$script" >"$HOME/output"
[[ -d $HOME/.cache/project/target && -e $HOME/cache-calls ]]
printf 'PASS: pgrep errors keep build output but allow cache trimming\n'

new_home dry-run
export TEST_USE=50
bash "$script" --dry-run --force >"$HOME/output"
[[ -d $HOME/.cache/project/target && ! -e $HOME/cache-calls && ! -e $HOME/docker-calls ]]
jq -e 'select(.action == "rust_target" and .status == "would_remove")' "$HOME/output" >/dev/null
printf 'PASS: forced dry run below threshold reports without deletion\n'

new_home protected
mkdir -p "$HOME/.codex/target" "$HOME/.t3" "$HOME/.cache/kimsufi-hunter/"{private,codex,scratch}
ln -s "$HOME/.codex" "$HOME/.cache/linked"
mkdir -p "$HOME/.cache/codex-runtimes/"{codex-runtime-install-old,codex-runtime-install-new}
touch -t 202001010000 "$HOME/.cache/codex-runtimes/codex-runtime-install-old"
bash "$script" >"$HOME/output"
[[ -d $HOME/.codex/target && -d $HOME/.t3 && -L $HOME/.cache/linked ]]
[[ -d $HOME/.cache/kimsufi-hunter/private && -d $HOME/.cache/kimsufi-hunter/codex && -d $HOME/.cache/kimsufi-hunter/scratch ]]
[[ ! -e $HOME/.cache/codex-runtimes/codex-runtime-install-old && -d $HOME/.cache/codex-runtimes/codex-runtime-install-new ]]
printf 'PASS: protected paths and symlink targets kept; only stale runtime removed\n'

new_home rotation
mkdir -p "$HOME/Library/Logs"
for ((i = 0; i < 15000; i++)); do
	printf '{"old":"1234567890123456789012345678901234567890123456789012345678901234567890"}\n'
done >"$HOME/Library/Logs/dev-disk-trim.log"
export TEST_USE=50
bash "$script" >"$HOME/output"
[[ $(wc -c <"$HOME/Library/Logs/dev-disk-trim.log") -lt 1048576 ]]
jq -e -s '.[-1].action == "threshold"' "$HOME/Library/Logs/dev-disk-trim.log" >/dev/null
printf 'PASS: log rotation preserves complete JSON lines below 1 MiB\n'

for command in cargo rustc cargo-nextest clippy-driver rustdoc 'npm ci' 'npm install' \
	'node /lib/npm/bin/npm-cli.js install' 'playwright install' \
	'node /lib/playwright/cli.js install' 'uv sync' 'docker build .' \
	'docker buildx build .' 'docker --context local build .' 'docker-buildx build .'; do
	new_home command
	export TEST_BUSY_COMMAND="$command" TEST_EARLY=1
	bash "$script" >"$HOME/output"
	[[ -d $HOME/.cache/project/target && -e $HOME/cache-calls ]]
done
printf 'PASS: Rust, npm, Playwright, uv and Docker command forms keep targets\n'

new_home helpers
mkdir -p "$HOME/code/kimsufi/tools" "$HOME/.cache/kimsufi-hunter/scratch"
cat >"$HOME/code/kimsufi/tools/dev-clean.sh" <<'HELPER'
#!/usr/bin/env bash
set -euo pipefail
rm -rf "$HOME/.cache/kimsufi-hunter/scratch"
HELPER
ln -s "$HOME/code/kimsufi" "$HOME/code/alias"
mkdir -p "$HOME/code/kimsufi-copy/tools"
cp "$HOME/code/kimsufi/tools/dev-clean.sh" "$HOME/code/kimsufi-copy/tools/dev-clean.sh"
# A worktree may modify the helper, so content comparison alone is insufficient.
git -C "$HOME/code/kimsufi" init -q
git -C "$HOME/code/kimsufi" add tools/dev-clean.sh
git -C "$HOME/code/kimsufi" -c user.name=Test -c user.email=test@example.invalid commit -qm 'Add helper fixture'
git -C "$HOME/code/kimsufi" worktree add -q -b fixture "$HOME/code/kimsufi-worktree"
printf '# worktree variant\n' >>"$HOME/code/kimsufi-worktree/tools/dev-clean.sh"
bash "$script" >"$HOME/output"
[[ -d $HOME/.cache/kimsufi-hunter/scratch ]]
jq -e 'select(.action == "dev_clean" and .status == "unsafe_path")' "$HOME/output" >/dev/null
git -C "$HOME/code/kimsufi-worktree" restore tools/dev-clean.sh
git -C "$HOME/code/kimsufi" worktree remove "$HOME/code/kimsufi-worktree"
git -C "$HOME/code/kimsufi" worktree prune
git -C "$HOME/code/kimsufi" branch -D fixture >/dev/null
printf 'PASS: unsafe Kimsufi helper, copies, worktrees and symlink alias never execute\n'

new_home docker-hung
export TEST_DOCKER_HANG=1
started=$SECONDS
bash "$script" >"$HOME/output"
[[ ! -e $HOME/docker-calls && $((SECONDS - started)) -lt 20 ]]
jq -e 'select(.action == "final")' "$HOME/output" >/dev/null
printf 'PASS: hung Docker probe times out and cleanup completes\n'
