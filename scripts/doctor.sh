#!/usr/bin/env bash
# ── Dotfiles Doctor — drift detection & repair ──────────────────────
# Verifies that every config the dotfiles repo manages is correctly installed:
# symlinks point at the repo, copied files exist, key tools are on PATH, and
# no tracked file has leaked a machine-specific path.
#
# Usage:
#   doctor.sh             # check only (exit 1 on hard failures)
#   doctor.sh --fix       # re-link drifted configs, back up + repair, seed .zshrc.local
#   doctor.sh --quiet     # show only warnings/failures (suppress ✓ lines)
#
# Safe to run repeatedly. Never deletes without backing up.
set -uo pipefail

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'; DIM=$'\033[2m'; NC=$'\033[0m'
[[ -t 1 ]] || { RED=""; GREEN=""; YELLOW=""; BLUE=""; DIM=""; NC=""; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLATFORM="$(uname -s)"

# Match the interactive shell's PATH so command checks are accurate even when
# doctor runs from a minimal environment (cron, non-login shell, CI).
[[ -d /opt/homebrew/bin ]] && PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
[[ -d /usr/local/bin ]] && PATH="/usr/local/bin:$PATH"
[[ -d "$HOME/.local/bin" ]] && PATH="$HOME/.local/bin:$PATH"

FIX=0; QUIET=0
for _a in "$@"; do
    case "$_a" in
        --fix|-f) FIX=1 ;;
        --quiet|-q) QUIET=1 ;;
        -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) echo "unknown flag: $_a" >&2; exit 2 ;;
    esac
done

FAILS=0; WARNS=0
ok()   { [[ $QUIET -eq 0 ]] && echo "  ${GREEN}✓${NC} $1"; }
warn() { echo "  ${YELLOW}⚠${NC} $1"; WARNS=$((WARNS+1)); }
bad()  { echo "  ${RED}✗${NC} $1"; FAILS=$((FAILS+1)); }
info() { echo -e "  ${BLUE}ℹ${NC} $1"; }
hdr()  { echo -e "\n${BLUE}── $1 ──${NC}"; }

# relink <repo-relative-src> <dst> — make dst a symlink to repo src.
# Backs up an existing regular file before replacing it.
relink() {
    local src="$REPO_DIR/$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        local bkup
        bkup="${dst}.backup.$(date +%s)"
        cp -r "$dst" "$bkup" && warn "backed up $dst → $bkup"
    fi
    ln -sfn "$src" "$dst" && info "linked $dst → $1"
}

# ── 1. Symlinks (should point into the repo) ────────────────────────
hdr "Symlinked configs"
check_link() {
    local rel="$1" dst="$2" src="$REPO_DIR/$1"
    if [[ ! -e "$src" && ! -L "$src" ]]; then bad "$rel: source missing in repo"; return; fi
    # Resolve current state into $state ("ok" or a human drift reason).
    local state="ok" tgt=""
    if [[ -L "$dst" ]]; then
        tgt=$(readlink "$dst")
        [[ "$tgt" != /* ]] && tgt="$(cd "$(dirname "$dst")" && cd "$(dirname "$tgt")" && pwd)/$(basename "$tgt")"
        [[ "$tgt" -ef "$src" ]] || state="$dst → $tgt (expected repo)"
    elif [[ -e "$dst" ]]; then
        state="$dst: regular file, not a symlink (drift)"
    else
        state="$dst: missing"
    fi
    if [[ "$state" == "ok" ]]; then ok "$dst"; return; fi
    # Drift: count as failure only if we can't (or don't) repair it.
    if [[ $FIX -eq 1 ]]; then
        if relink "$rel" "$dst"; then ok "repaired: $dst → $rel"; else bad "could not repair $dst ($state)"; fi
    else
        bad "$state"
    fi
}

check_link "tmux/tmux.conf"            "$HOME/.tmux.conf"
check_link "starship/starship.toml"    "$HOME/.config/starship.toml"
check_link "zsh/.zshrc"                "$HOME/.zshrc"
check_link "git/.gitconfig"            "$HOME/.gitconfig"
check_link "bat/config"                "$HOME/.config/bat/config"
check_link "nano/.nanorc"              "$HOME/.nanorc"
check_link "vim/.vimrc"                "$HOME/.vimrc"
check_link "claude/statusline.sh"      "$HOME/.claude/statusline.sh"
[[ "$PLATFORM" == "Darwin" ]] && check_link "ghostty/config" "$HOME/.config/ghostty/config"
for _rule in "$REPO_DIR"/claude/rules/*.md; do
    [[ -f "$_rule" ]] || continue
    check_link "claude/rules/$(basename "$_rule")" "$HOME/.claude/rules/$(basename "$_rule")"
done

# ── 2. Copied configs (owned/rewritten by an app → not symlinked) ───
hdr "Copied configs (app-owned)"
check_copy() {
    local src="$REPO_DIR/$1" dst="$2"
    if [[ -e "$dst" && ! -L "$dst" ]]; then ok "$dst present"; return; fi
    # Missing, or wrongly a symlink → (re)seed.
    if [[ -L "$dst" ]]; then warn "$dst is a symlink — $1 rewrites this file and breaks the link"; rm -f "$dst"; fi
    if [[ $FIX -eq 1 ]]; then
        mkdir -p "$(dirname "$dst")"
        if cp "$src" "$dst"; then ok "seeded: $dst"; else bad "could not copy $dst"; fi
    else
        bad "$dst: missing (run --fix to seed)"
    fi
}
check_copy "claude/settings.json" "$HOME/.claude/settings.json"

# ── 3. Machine-local rc exists ──────────────────────────────────────
hdr "Machine-local overrides"
# shellcheck disable=SC2088  # tilde shown for readability, not expansion
if [[ -f "$HOME/.zshrc.local" ]]; then
    ok "~/.zshrc.local present"
else
    # shellcheck disable=SC2088
    warn "~/.zshrc.local missing (optional — only needed if installers append to your rc)"
    [[ $FIX -eq 1 ]] && cp "$REPO_DIR/zsh/.zshrc.local.example" "$HOME/.zshrc.local" \
        && info "seeded ~/.zshrc.local from example (uncomment blocks as needed)"
fi

# ── 4. Key commands on PATH ─────────────────────────────────────────
hdr "Tools on PATH"
check_cmd() {
    if command -v "$1" &>/dev/null; then ok "$1"; else warn "$1 not on PATH"; fi
}
for _c in zsh tmux starship atuin delta eza bat fzf zoxide rg fd git; do
    check_cmd "$_c"
done
if [[ "$PLATFORM" == "Darwin" ]]; then check_cmd brew; else check_cmd rbw; fi

# ── 5. Portability scan — machine-specific paths in tracked files ───
hdr "Portability scan (tracked files)"
if git -C "$REPO_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    _hits=$(git -C "$REPO_DIR" grep -nE '/Users/[^/"]+|/home/[^/"]+' -- . \
        ':(exclude)*.md' ':(exclude)*.example' ':(exclude)*.backup.*' 2>/dev/null || true)
    if [[ -n "$_hits" ]]; then
        echo "$_hits" | while IFS= read -r _line; do warn "hardcoded path: ${_line#"$REPO_DIR"/}"; done
        echo -e "  ${DIM}Move machine-specific blocks into ~/.zshrc.local (gitignored).${NC}"
    else ok "no /Users or /home paths in tracked files"
    fi
else
    info "not a git work-tree — skipped"
fi

# ── Summary ─────────────────────────────────────────────────────────
echo ""
if (( FAILS > 0 )); then
    echo -e "${RED}✗ ${FAILS} failure(s), ${WARNS} warning(s)${NC}"
    [[ $FIX -eq 0 ]] && echo -e "  ${DIM}Run 'dots-doctor --fix' to repair symlinks and copy missing configs.${NC}"
    exit 1
elif (( WARNS > 0 )); then
    echo -e "${YELLOW}⚠ ${WARNS} warning(s), no hard failures${NC}"
    exit 0
else
    echo -e "${GREEN}✓ all checks passed${NC}"
    exit 0
fi
