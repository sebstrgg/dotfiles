# ── Dotfiles — zsh configuration ─────────────────────
# Managed by dotfiles: https://github.com/sebstrgg/dotfiles
# Symlinked to ~/.zshrc
# Works on macOS (Ghostty) and Linux (SSH/WSL2)

# ── Path ──────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── nvm (Node.js version manager) ────────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# ── tmux auto-start ──────────────────────────────────
# Attach to (or create) tmux session when entering a terminal:
#   - macOS: only inside Ghostty (not other terminals/IDEs)
#   - SSH:   always (this is the remote dev workflow)
# Skip if already inside tmux.
if [[ -z "$TMUX" ]]; then
  if [[ "$TERM_PROGRAM" == "ghostty" ]] || [[ -n "$SSH_CONNECTION" ]]; then
    if [[ -f "$HOME/.tmux/session-dev.sh" ]]; then
      exec bash "$HOME/.tmux/session-dev.sh"
    else
      tmux attach -t main 2>/dev/null || tmux new -s main
    fi
  fi
fi

printf '\033[?1003l\033[?1006l'

# ── Environment ───────────────────────────────────────
export CLAUDE_CODE_NO_FLICKER=1
export BAT_THEME="Catppuccin Mocha"
export EDITOR="nano"

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
# eza (modern ls with icons and colors)
alias ls="eza --icons"
alias ll="eza --icons -la"
alias lt="eza --icons --tree --level=2"

# bat (cat with syntax highlighting)
alias cat="bat --paging=never"
alias catp="bat"

# ── Tool initialization ──────────────────────────────
# fzf shell integration (--zsh requires 0.48+, older versions use key-bindings/completion scripts)
if fzf --zsh &>/dev/null; then
  eval "$(fzf --zsh)"
elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
  [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
fi
eval "$(zoxide init zsh --cmd cd)"  # smart cd that learns your directories

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

# ── Starship prompt (keep at end of .zshrc) ──────────
eval "$(starship init zsh)"

# bun completions
[ -s "/home/seb/.bun/_bun" ] && source "/home/seb/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# >>> claude-auto-retry >>>
claude() {
  if [ "${CLAUDE_AUTO_RETRY_ACTIVE}" = "1" ]; then
    command claude "$@"
    return $?
  fi
  export CLAUDE_AUTO_RETRY_ACTIVE=1
  local _car_old_int_trap _car_old_term_trap
  _car_old_int_trap=$(trap -p INT)
  _car_old_term_trap=$(trap -p TERM)
  trap 'unset CLAUDE_AUTO_RETRY_ACTIVE' INT TERM
  node "/home/seb/.nvm/versions/node/v24.14.1/lib/node_modules/claude-auto-retry/src/launcher.js" "$@"
  local _car_exit=$?
  unset CLAUDE_AUTO_RETRY_ACTIVE
  # Restore previous traps instead of clobbering them
  eval "${_car_old_int_trap:-trap - INT}"
  eval "${_car_old_term_trap:-trap - TERM}"
  return $_car_exit
}
# <<< claude-auto-retry <<<

