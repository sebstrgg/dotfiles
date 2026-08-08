# ── Dotfiles — zsh configuration ─────────────────────
# Managed by dotfiles: https://github.com/sebstrgg/dotfiles
# Symlinked to ~/.zshrc. Machine-local overrides live in ~/.zshrc.local
# (gitignored) and are sourced near the end. Works on macOS (Ghostty) and
# Linux (SSH/WSL2).
#
# Repair / drift check:  dots-doctor        (or scripts/doctor.sh --fix)

# ── Path ──────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── nvm (Node.js version manager) ────────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# ── tmux ──────────────────────────────────────────────
# Ghostty starts as a normal shell. Run `main` to attach to the main session.
# SSH keeps auto-attaching because that is the remote dev workflow.
alias main='tmux new-session -A -s main'

if [[ -z "$TMUX" && -n "$SSH_CONNECTION" ]]; then
  if [[ -f "$HOME/.tmux/session-dev.sh" ]]; then
    exec bash "$HOME/.tmux/session-dev.sh"
  else
    tmux attach -t main 2>/dev/null || tmux new -s main
  fi
fi

# Disable Ghostty mouse-tracking modes that leak into tmux/SSH sessions.
printf '\033[?1003l\033[?1006l'

# ── Environment ───────────────────────────────────────
export CLAUDE_CODE_NO_FLICKER=1
export BAT_THEME="Catppuccin Mocha"
export EDITOR="nano"
export LANG="${LANG:-en_US.UTF-8}"

# ── SSH agent — Bitwarden-backed on both platforms ────
# macOS: Bitwarden Desktop's built-in SSH agent (requires Desktop app running + SSH agent enabled in settings)
# Linux / WSL: rbw's built-in SSH agent (requires `rbw unlock` in the session or another)
if [[ "$OSTYPE" == darwin* ]]; then
    _bw_sock="$HOME/.bitwarden-ssh-agent.sock"
    [[ -S "$_bw_sock" ]] && export SSH_AUTH_SOCK="$_bw_sock"
    unset _bw_sock
else
    _rbw_sock="${XDG_RUNTIME_DIR:-/run/user/$UID}/rbw/ssh-agent-socket"
    [[ -S "$_rbw_sock" ]] && export SSH_AUTH_SOCK="$_rbw_sock"
    unset _rbw_sock
fi

# ── History ───────────────────────────────────────────
# Persistent, shared history — required for zsh-autosuggestions to have
# anything to suggest from.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY          # share history across all sessions
setopt INC_APPEND_HISTORY     # write immediately, not just on exit
setopt HIST_IGNORE_ALL_DUPS   # drop older duplicate of the same command
setopt HIST_IGNORE_SPACE      # commands prefixed with a space are not saved
setopt HIST_REDUCE_BLANKS     # trim redundant whitespace
setopt HIST_VERIFY            # show !-expansions before running them
setopt AUTO_CD                # bare dir name cds into it
setopt AUTO_PUSHD             # cd pushes the dir stack → `cd -` cycles back
setopt PUSHD_IGNORE_DUPS

# ── API keys (not in git) ────────────────────────────
[[ -f ~/.env.ai ]] && source ~/.env.ai

# ── fzf Catppuccin Mocha colors ──────────────────────
FZF_COLORS="bg+:#313244,spinner:#f5e0dc,hl:#f38ba8"
FZF_COLORS+=",fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc"
FZF_COLORS+=",marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
# selected-bg requires fzf 0.48+
[[ "$(fzf --version 2>/dev/null | cut -d. -f1-2)" > "0.47" ]] && FZF_COLORS+=",selected-bg:#45475a"
export FZF_DEFAULT_OPTS="--color=$FZF_COLORS --multi"

# ── Aliases ───────────────────────────────────────────
# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias -- -='cd -'            # jump to previous dir

# eza (modern ls with icons and colors)
alias ls="eza --icons"
alias ll="eza --icons -la --git"
alias lt="eza --icons --tree --level=2"
alias la="eza --icons -a"

# bat (cat with syntax highlighting)
alias cat="bat --paging=never"
alias catp="bat"

# Safety / quality of life
alias cp='cp -iv'            # confirm + verbose on overwrite
alias mv='mv -iv'
alias mkdir='mkdir -p'
alias reload='exec zsh'      # full shell restart
alias path='print -l $path'  # print PATH one entry per line
alias ports='lsof -i -P -n | grep LISTEN'
alias myip='curl -s ifconfig.me && echo'
alias diff='diff --color=auto'

# extract <archive> — handles tar/zip/rar/7z
extract() {
  case "$1" in
    *.tar.gz|*.tgz)   tar xzf "$1" ;;
    *.tar.bz2|*.tbz2) tar xjf "$1" ;;
    *.tar.xz|*.txz)   tar xJf "$1" ;;
    *.tar)            tar xf  "$1" ;;
    *.zip)            unzip   "$1" ;;
    *.rar)            unrar x "$1" ;;
    *.7z)             7z x    "$1" ;;
    *) echo "extract: unknown archive type: $1" >&2; return 1 ;;
  esac
}

# ── Git aliases ──────────────────────────────────────
alias g='git'
alias gs='git status -sb'
alias gd='git diff'
alias gdc='git diff --cached'
alias gl='git log --oneline --graph --decorate -20'
alias gp='git push'
alias gpl='git pull --rebase'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -v'
alias gco='git checkout'
alias gb='git branch -vv'
alias gcb='git checkout -b'
alias gm='git merge'
alias gwip='git add -A && git commit -m "wip"'
alias gundo='git reset --soft HEAD~1'   # undo last commit, keep changes staged

# ── tmux aliases ─────────────────────────────────────
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tls='tmux ls'
alias tk='tmux kill-session -t'

# ── Bitwarden (rbw) shortcuts ─────────────────────────
if command -v rbw &>/dev/null; then
    alias bws='rbw get'                    # print password:      bws atuin
    alias bwu='rbw get --field=username'   # print username
    alias bwn='rbw get --field=notes'      # print notes (used for atuin key etc.)
    alias bwl='rbw list'                   # list all vault items
    # bwf <item> <field> — fetch a specific custom field
    bwf() { rbw get --field="$2" "$1"; }
fi

# ── Dotfiles convenience ─────────────────────────────
alias dots='cd ~/dotfiles'
dots-doctor() { bash "$HOME/dotfiles/scripts/doctor.sh" "${@}"; }
dots-update() {
  builtin cd "$HOME/dotfiles" && git pull --ff-only || return
  echo "Run 'dots-doctor --fix' to re-link any changed configs."
}

# ── Tool initialization ──────────────────────────────
# fzf shell integration (--zsh requires 0.48+, older versions use key-bindings/completion scripts)
if fzf --zsh &>/dev/null; then
  eval "$(fzf --zsh)"
elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
  [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
fi

# ── Zsh plugins (platform-aware paths) ───────────────
# Catppuccin theme for zsh-syntax-highlighting (must be before plugin load)
source ~/.config/zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh

# Autosuggestion color — default `fg=8` is nearly invisible on Catppuccin Mocha.
# Use overlay0 from the palette so ghost text is dim but readable.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6c7086"

if [[ "$OSTYPE" == darwin* ]]; then
  # macOS: Homebrew-installed plugins
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [[ "$OSTYPE" == linux* ]]; then
  # Linux: apt-installed plugins
  [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# ── Atuin (shell history sync) ───────────────────────
# Takes over Ctrl+R. Up-arrow remains host-local (configured in config.toml).
if command -v atuin &>/dev/null; then
    eval "$(atuin init zsh)"
fi

# ── Starship prompt ───────────────────────────────────
eval "$(starship init zsh)"

# ── Machine-local overrides ───────────────────────────
# Installer-managed blocks (bun, shell completions, claude-auto-retry wrapper)
# live in ~/.zshrc.local so installers appending to the rc can't corrupt this
# tracked file. Sourced BEFORE zoxide — none of them touch chpwd_functions,
# so they don't interfere with zoxide's hook.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# ── zoxide (smart cd) — KEEP AT THE VERY END ──────────
# zoxide's doctor verifies its chpwd hook is intact when `cd` runs; it must be
# initialized after everything else so later `eval`/`source` lines can't
# clobber the hook array. Moving anything below this re-triggers the warning.
eval "$(zoxide init zsh --cmd cd)"  # smart cd that learns your directories


# Added by Antigravity CLI installer
export PATH="/Users/sebastian/.local/bin:$PATH"
