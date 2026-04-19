#!/usr/bin/env bash
set -euo pipefail

# ── Dotfiles Installer ────────────────────────────────
# Bootstraps a macOS or Ubuntu/WSL2 machine with the full terminal environment.
# Safe to run multiple times — backs up existing configs, never overwrites silently.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { echo -e "  ${BLUE}ℹ${NC} $1"; }
ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
error() { echo -e "  ${RED}✗${NC} $1"; }

confirm() { read -rp "$1 [y/N] " _r; [[ "$_r" =~ ^[Yy]$ ]]; }

# Back up and symlink a file.
link_config() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        warn "Backing up $dst → ${dst}.backup.$(date +%s)"
        cp -r "$dst" "${dst}.backup.$(date +%s)"
    fi
    ln -sf "$src" "$dst"
    ok "$(basename "$dst") → $dst"
}

# Copy a file (for theme files that shouldn't be symlinks).
copy_config() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
    ok "$(basename "$dst") → $dst (copied)"
}

# retry_menu <section-name> <cmd...> — loop cmd until it succeeds.
# Returns 0 on success, 2 if user skips, exits cleanly on abort.
retry_menu() {
    local section="$1"; shift
    while ! "$@"; do
        echo ""
        echo -e "  ${RED}✗${NC} ${section} failed."
        echo ""
        echo "  What next?"
        echo "    [1] Retry"
        echo "    [2] Skip section"
        echo "    [3] Abort install"
        local _c
        read -rp "  Choice: " _c
        case "$_c" in
            1) echo "" ;;
            2) return 2 ;;
            3) abort_clean "User aborted at: $section" ;;
            *) echo "  Enter 1, 2, or 3." ;;
        esac
    done
}

abort_clean() {
    echo -e "${YELLOW}  Install aborted: $1${NC}"
    echo "  Resume later with: ./install.sh"
    echo "  Or bypass idempotency guards with: FORCE_SETUP=1 ./install.sh"
    exit 0
}

section_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Step $1 of ${TOTAL_STEPS} — $2${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "  What this does:   $3"
    echo "  What we'll ask:   $4"
    echo "  Skip if:          $5"
    echo ""
}

# ── Platform Detection ───────────────────────────────
OS="$(uname -s)"
case "$OS" in
    Darwin) PLATFORM="macos" ;;
    Linux)  PLATFORM="linux" ;;
    *)      error "Unsupported OS: $OS"; exit 1 ;;
esac

# ── Opening banner ───────────────────────────────────
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Dotfiles Installer                      ║${NC}"
echo -e "${BLUE}║  Catppuccin Mocha | Ghostty + tmux       ║${NC}"
echo -e "${BLUE}║  Platform: ${PLATFORM}$(printf '%*s' $((27 - ${#PLATFORM})) '')║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Headless Mac mini detection ───────────────────────
HEADLESS_MODE=0
if [[ "$PLATFORM" == "macos" ]]; then
    echo "  ────────────────────────────────────────────────────────────"
    echo "  Is this a headless Mac mini? (always on, no display attached)"
    echo "  YES: pmset always-on, Wake-on-LAN, VNC tuning."
    echo "  NO:  laptop or desktop with a display attached."
    echo "  ────────────────────────────────────────────────────────────"
    read -rp "  Configure as headless Mac mini? [y/N] " _reply
    case "$_reply" in
        [Yy]*) HEADLESS_MODE=1; ok "Headless Mac mini mode enabled" ;;
        *)     HEADLESS_MODE=0 ;;
    esac
fi

# ── Platform-aware step count + section titles ───────
if [[ "$PLATFORM" == "macos" ]]; then
    TOTAL_STEPS=9
    SECTION_TITLES=(
        "System packages (Homebrew bundle)"
        "macOS app preferences (plists, Alfred, LinearMouse)"
        "macOS defaults and hotkeys"
        "Node.js runtime (nvm + LTS)"
        "Configuration files (symlinks, themes, tmux, Claude Code)"
        "GitHub CLI authentication"
        "Bitwarden / Vaultwarden"
        "Atuin history sync"
        "Post-flight validation"
    )
else
    TOTAL_STEPS=8
    SECTION_TITLES=(
        "System packages (apt + cargo rbw + delta + starship + atuin)"
        "Node.js runtime (nvm + LTS)"
        "Configuration files (symlinks, themes, tmux, Claude Code)"
        "Linux services (Docker Engine optional)"
        "GitHub CLI authentication"
        "Bitwarden / Vaultwarden (rbw)"
        "Atuin history sync"
        "Post-flight validation"
    )
fi

# ── Pre-flight plan ───────────────────────────────────
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Pre-flight — what's about to happen${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
_headless_str="no"; [[ "$HEADLESS_MODE" == "1" ]] && _headless_str="yes"
echo "  ${TOTAL_STEPS} sections  platform=${PLATFORM}  headless=${_headless_str}"
for _i in "${!SECTION_TITLES[@]}"; do
    echo "    $(( _i + 1 )). ${SECTION_TITLES[$_i]}"
done
echo ""
echo "  FORCE_SETUP=1 ./install.sh to bypass idempotent skips"
read -rp "  Continue? [Y/n] " _pf_reply
[[ "${_pf_reply}" =~ ^[Nn] ]] && { info "Aborted. Run ./install.sh when ready."; exit 0; }

# ── Step 1: Install packages ─────────────────────────────────────────────────
if [[ "$PLATFORM" == "macos" ]]; then
    section_header 1 "${SECTION_TITLES[0]}" \
        "Installs all CLI tools, apps, and fonts via Homebrew Brewfile." \
        "Nothing — runs unattended (Homebrew may prompt for sudo)." \
        "n/a — always runs."

    if ! command -v brew &>/dev/null; then
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        ok "Homebrew installed"
    else
        ok "Homebrew already installed"
    fi
    # Refresh PATH so brew-installed commands are visible for the rest of this script.
    # Fixes silent failures of post-bundle `command -v <pkg>` checks when install.sh
    # was invoked from a shell that didn't already have brew on PATH.
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    info "Installing packages from Brewfile..."
    brew bundle --file="$SCRIPT_DIR/Brewfile"
    ok "All packages installed"

elif [[ "$PLATFORM" == "linux" ]]; then
    section_header 1 "${SECTION_TITLES[0]}" \
        "Installs zsh, tmux, and all CLI tools via apt, cargo, and official installers." \
        "Nothing for most tools; Docker prompt in Step 4." \
        "n/a — always runs."

    info "Installing packages via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        zsh tmux bat eza fzf zoxide nano jq curl git build-essential \
        openssh-server mosh gh zsh-autosuggestions zsh-syntax-highlighting \
        ripgrep fd-find direnv shellcheck
    ok "apt packages installed"

    if ! command -v delta &>/dev/null; then
        info "Installing git-delta..."
        DELTA_VERSION="0.18.2"
        curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_$(dpkg --print-architecture).deb" \
            -o /tmp/git-delta.deb
        sudo dpkg -i /tmp/git-delta.deb && rm -f /tmp/git-delta.deb
        ok "git-delta installed"
    else
        ok "git-delta already installed"
    fi

    if ! command -v starship &>/dev/null; then
        info "Installing Starship prompt..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
        ok "Starship installed"
    else
        ok "Starship already installed"
    fi

    # atuin — not in apt, use official installer
    if ! command -v atuin &>/dev/null; then
        info "Installing atuin (shell history sync)..."
        curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
        # Installer drops binary at ~/.atuin/bin/atuin — symlink into ~/.local/bin
        # for PATH stability (our zshrc handles init via `eval "$(atuin init zsh)"`).
        if [[ -x "$HOME/.atuin/bin/atuin" ]]; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$HOME/.atuin/bin/atuin" "$HOME/.local/bin/atuin"
        fi
        ok "atuin installed"
        # Strip the installer's self-added shell rc lines — we own those files.
        for _rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
            if [[ -f "$_rc" ]] && grep -qF '.atuin/bin/env' "$_rc"; then
                sed -i '/\.atuin\/bin\/env/d' "$_rc"
                info "Removed atuin installer's auto-appended line from $_rc"
            fi
        done
    else
        ok "atuin already installed"
    fi

    # rbw + pinentry prerequisite
    if ! dpkg -l | grep -q '^ii  pinentry-curses '; then
        sudo apt-get install -y -qq pinentry-curses
        ok "pinentry-curses installed"
    fi
    if ! command -v rbw &>/dev/null; then
        info "Installing rbw (Bitwarden CLI)..."
        if apt-cache show rbw >/dev/null 2>&1; then
            sudo apt-get install -y -qq rbw
        else
            if ! command -v cargo &>/dev/null; then
                info "Installing Rust toolchain (required to build rbw)..."
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
                    | sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path
                # shellcheck disable=SC1091
                [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
                ok "Rust toolchain installed"
            fi
            info "Building rbw via cargo (2-5 minutes)..."
            cargo install --locked rbw
        fi
        if [[ -x "$HOME/.cargo/bin/rbw" ]]; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$HOME/.cargo/bin/rbw" "$HOME/.local/bin/rbw"
            ln -sf "$HOME/.cargo/bin/rbw-agent" "$HOME/.local/bin/rbw-agent" 2>/dev/null || true
        fi
        ok "rbw installed"
    else
        ok "rbw already installed"
    fi

    # Canonical aliases: batcat→bat, fdfind→fd
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(which batcat)" "$HOME/.local/bin/bat"
        ok "bat alias created (batcat → bat)"
    fi
    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
        ok "fd alias created (fdfind → fd)"
    fi

    if [[ "$SHELL" != *"zsh"* ]]; then
        info "Setting zsh as default shell..."
        chsh -s "$(which zsh)"
        ok "Default shell set to zsh"
    else
        ok "zsh is already default shell"
    fi
fi

# ── macOS Steps 2 & 3: App preferences + defaults/hotkeys ───────────────────
if [[ "$PLATFORM" == "macos" ]]; then
    section_header 2 "${SECTION_TITLES[1]}" \
        "Imports plist prefs for apps, restores LinearMouse config, points Alfred at the repo." \
        "Nothing — runs unattended." \
        "n/a — always runs."

    MAC_APPS="$SCRIPT_DIR/mac-apps"
    if [[ -d "$MAC_APPS/plists" ]]; then
        for plist in "$MAC_APPS/plists"/*.plist; do
            [[ -f "$plist" ]] || continue
            domain=$(basename "$plist" .plist)
            defaults import "$domain" "$plist"
            ok "Restored prefs: $domain"
        done
        killall cfprefsd 2>/dev/null || true
    fi
    LM_JSON="$MAC_APPS/linearmouse/linearmouse.json"
    if [[ -f "$LM_JSON" ]]; then
        mkdir -p "$HOME/Library/Application Support/LinearMouse"
        cp "$LM_JSON" "$HOME/Library/Application Support/LinearMouse/linearmouse.json"
        ok "Restored LinearMouse JSON"
    fi
    # Alfred — point at the committed sync folder so future changes show in git diff.
    if [[ -d "$MAC_APPS/alfred" ]]; then
        defaults write com.runningwithcrayons.Alfred-Preferences syncfolder -string "$MAC_APPS/alfred"
        ok "Alfred sync folder → $MAC_APPS/alfred"
    fi

    section_header 3 "${SECTION_TITLES[2]}" \
        "Applies macOS defaults, symbolic hotkey remaps, and (headless) pmset/VNC tuning." \
        "Nothing — runs unattended." \
        "n/a — always runs."

    info "Applying macOS hotkey remaps..."
    bash "$SCRIPT_DIR/mac-apps/hotkeys/symbolichotkeys.sh"
    ok "Hotkey remaps applied"

    info "Applying macOS defaults..."
    bash "$SCRIPT_DIR/mac-apps/defaults/macos-defaults.sh"
    ok "macOS defaults applied"

    if [[ "$HEADLESS_MODE" == "1" ]]; then
        info "Configuring always-on power settings (headless mode)..."
        bash "$SCRIPT_DIR/mac-apps/pmset/always-on.sh"
        ok "Power settings applied"
        info "Tuning Screen Sharing (VNC fallback path)..."
        bash "$SCRIPT_DIR/mac-apps/screensharing/tune.sh"
        ok "Screen Sharing tuned"
    else
        info "Skipping pmset + Screen Sharing tuning (non-headless mode)"
    fi
fi

# ── nvm (macOS = 4, Linux = 2) ───────────────────────────────────────────────
[[ "$PLATFORM" == "macos" ]] && _nvm_step=4 || _nvm_step=2
section_header "$_nvm_step" "${SECTION_TITLES[$_nvm_step - 1]}" \
    "Installs nvm and the current Node.js LTS release." \
    "Nothing — runs unattended." \
    "Already done — skips if ~/.nvm exists."

if [[ ! -d "$HOME/.nvm" ]]; then
    info "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    nvm install --lts
    ok "nvm + Node.js LTS installed"
else
    ok "nvm already installed"
fi

# ── Configuration files (macOS = 5, Linux = 3) ───────────────────────────────
[[ "$PLATFORM" == "macos" ]] && _cfg_step=5 || _cfg_step=3
section_header "$_cfg_step" "${SECTION_TITLES[$_cfg_step - 1]}" \
    "Symlinks dotfiles, copies theme files, installs tmux plugins, links Claude Code config." \
    "Nothing — runs unattended. Backs up any existing non-symlink files." \
    "n/a — always runs (idempotent)."

info "Symlinking configuration files..."
link_config "$SCRIPT_DIR/tmux/tmux.conf"         "$HOME/.tmux.conf"
link_config "$SCRIPT_DIR/starship/starship.toml"  "$HOME/.config/starship.toml"
link_config "$SCRIPT_DIR/zsh/.zshrc"              "$HOME/.zshrc"
link_config "$SCRIPT_DIR/git/.gitconfig"          "$HOME/.gitconfig"
link_config "$SCRIPT_DIR/bat/config"              "$HOME/.config/bat/config"
link_config "$SCRIPT_DIR/nano/.nanorc"            "$HOME/.nanorc"
link_config "$SCRIPT_DIR/vim/.vimrc"              "$HOME/.vimrc"
# atuin/config.toml is NOT symlinked here — setup_atuin() writes it via sed+mv substitution
[[ "$PLATFORM" == "macos" ]] && link_config "$SCRIPT_DIR/ghostty/config" "$HOME/.config/ghostty/config"

info "Installing Catppuccin themes..."
copy_config "$SCRIPT_DIR/bat/themes/Catppuccin Mocha.tmTheme" "$HOME/.config/bat/themes/Catppuccin Mocha.tmTheme"
copy_config "$SCRIPT_DIR/git/catppuccin.gitconfig"             "$HOME/.config/git/catppuccin.gitconfig"
mkdir -p "$HOME/.config/zsh"
copy_config "$SCRIPT_DIR/zsh-syntax-highlighting/catppuccin_mocha-zsh-syntax-highlighting.zsh" \
            "$HOME/.config/zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh"

if command -v bat &>/dev/null; then
    bat cache --build &>/dev/null && ok "bat themes cached"
elif command -v batcat &>/dev/null; then
    batcat cache --build &>/dev/null && ok "bat themes cached"
fi

info "Setting up tmux..."
mkdir -p "$HOME/.tmux"
cp "$SCRIPT_DIR/tmux/cheatsheet.sh"  "$HOME/.tmux/cheatsheet.sh"  && chmod +x "$HOME/.tmux/cheatsheet.sh"
cp "$SCRIPT_DIR/tmux/session-dev.sh" "$HOME/.tmux/session-dev.sh" && chmod +x "$HOME/.tmux/session-dev.sh"
ok "tmux scripts installed"
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ -d "$TPM_DIR" ]]; then
    ok "TPM already installed"
else
    info "Installing TPM..."
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    ok "TPM installed"
fi

info "Setting up Claude Code configuration..."
mkdir -p "$HOME/.claude/rules"
link_config "$SCRIPT_DIR/claude/settings.json" "$HOME/.claude/settings.json"
link_config "$SCRIPT_DIR/claude/statusline.sh" "$HOME/.claude/statusline.sh"
chmod +x "$HOME/.claude/statusline.sh"
for rule in "$SCRIPT_DIR"/claude/rules/*.md; do
    [[ -f "$rule" ]] && link_config "$rule" "$HOME/.claude/rules/$(basename "$rule")"
done
ok "Claude Code config linked"

# ── Linux Step 4: Linux services (Docker) ────────────────────────────────────
if [[ "$PLATFORM" == "linux" ]]; then
    section_header 4 "${SECTION_TITLES[3]}" \
        "Optionally installs Docker Engine via the official apt repository." \
        "Confirm Docker installation [y/N]." \
        "Already installed, or if you don't need Docker."

    if ! command -v docker &>/dev/null; then
        if confirm "  Install Docker Engine?"; then
            info "Installing Docker Engine via official apt repository..."
            sudo install -m 0755 -d /etc/apt/keyrings
            sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            sudo chmod a+r /etc/apt/keyrings/docker.asc
            # shellcheck disable=SC1091  # /etc/os-release is runtime-only, not a checked input
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update -qq
            sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            sudo usermod -aG docker "$USER"
            sudo systemctl enable docker
            ok "Docker Engine installed (log out and back in for group changes)"
        else
            warn "Skipped Docker Engine installation"
        fi
    else
        ok "Docker already installed"
    fi

    warn "Manual steps remaining (see docs/wsl2-setup.md):"
    echo "    - /etc/ssh/sshd_config Tailscale-only, Tailscale install, WSL2 auto-start"
fi

# ── GitHub CLI auth (macOS = 6, Linux = 5) ───────────────────────────────────
[[ "$PLATFORM" == "macos" ]] && _gh_step=6 || _gh_step=5
section_header "$_gh_step" "${SECTION_TITLES[$_gh_step - 1]}" \
    "Authenticates the GitHub CLI so gh pr, gh repo, and gh auth work." \
    "Confirm auth [y/N]; opens a browser OAuth flow." \
    "Already authenticated — skips automatically."

SKIPPED_GH=0
if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null; then
        ok "GitHub CLI already authenticated"
    else
        if confirm "  Authenticate with GitHub CLI? (opens browser)"; then
            retry_menu "GitHub CLI auth" gh auth login || SKIPPED_GH=1
            [[ "$SKIPPED_GH" == "0" ]] && ok "GitHub CLI authenticated"
        else
            warn "Skipped GitHub CLI auth — run 'gh auth login' later"
            SKIPPED_GH=1
        fi
    fi
else
    warn "gh not found — skipping"; SKIPPED_GH=1
fi

# ── Bitwarden / Vaultwarden (macOS = 7, Linux = 6) ───────────────────────────
[[ "$PLATFORM" == "macos" ]] && _bw_step=7 || _bw_step=6

# macOS: bw (official Bitwarden CLI) — logs in + captures BW_SESSION for setup_atuin
setup_bw() {
    [[ "$PLATFORM" == "macos" ]] || return 0
    command -v bw >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || { warn "jq missing — bw setup skipped"; return 0; }

    local bw_status
    bw_status=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unknown")
    if [[ "$bw_status" == "unlocked" && -n "${BW_SESSION:-}" && -z "${FORCE_SETUP:-}" ]]; then
        ok "bw already unlocked"; return 0
    fi

    read -rp "  Configure bw now? [Y/n] " _yn
    [[ "$_yn" =~ ^[Nn]$ ]] && { warn "Skipped bw setup."; SKIPPED_BW=1; return 0; }

    local env_file="$HOME/.config/dotfiles/local.env" vw_url="" vw_email=""
    if [[ -f "$env_file" ]]; then
        # shellcheck disable=SC1090
        source "$env_file"
        vw_url="${VAULTWARDEN_URL:-}"; vw_email="${VAULTWARDEN_EMAIL:-}"
    fi
    if [[ -z "$vw_url" ]]; then
        echo "  [1] Self-hosted Vaultwarden (enter URL)"
        echo "  [2] Bitwarden Cloud (https://vault.bitwarden.com)"
        read -rp "  Choice [1/2]: " _choice
        case "$_choice" in
            1) read -rp "  Vaultwarden server URL: " vw_url ;;
            2) vw_url="https://vault.bitwarden.com" ;;
            *) warn "Invalid choice — skipping bw setup"; SKIPPED_BW=1; return 0 ;;
        esac
    else
        ok "Using cached Vaultwarden URL: $vw_url"
    fi
    [[ -z "$vw_email" ]] && read -rp "  Email: " vw_email

    bw config server "$vw_url" >/dev/null
    ok "bw server configured: $vw_url"
    mkdir -p "$(dirname "$env_file")"
    { grep -v '^VAULTWARDEN_' "$env_file" 2>/dev/null || true
      echo "VAULTWARDEN_URL=$vw_url"
      echo "VAULTWARDEN_EMAIL=$vw_email"; } > "$env_file.tmp" && mv "$env_file.tmp" "$env_file"

    bw_status=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unknown")
    if [[ "$bw_status" == "unauthenticated" ]]; then
        info "Logging in as $vw_email..."
        if ! retry_menu "bw login" bw login "$vw_email"; then
            warn "bw login skipped — retry later with: bw login"; SKIPPED_BW=1; return 0
        fi
    fi

    info "Unlocking bw vault — enter master password..."
    local _session
    # Not wrapped in retry_menu: `bw unlock --raw` must be in a $() subshell to
    # capture the session token. retry_menu can't capture stdout from its command.
    if ! _session=$(bw unlock --raw 2>/dev/null); then
        warn "bw unlock failed — retry manually: export BW_SESSION=\$(bw unlock --raw)"
        SKIPPED_BW=1; return 0
    fi
    export BW_SESSION="$_session"
    bw sync >/dev/null 2>&1 || true
    ok "bw unlocked; BW_SESSION exported for this script run"
}

# Linux: rbw configuration
setup_rbw() {
    command -v rbw >/dev/null 2>&1 || return 0

    local existing_email
    existing_email=$(rbw config show 2>/dev/null | grep -oP '(?<="email": ")[^"]*' || true)
    if [[ -n "$existing_email" && "$existing_email" != "null" && -z "${FORCE_SETUP:-}" ]]; then
        ok "rbw already configured (email: $existing_email)"
        if ! rbw unlocked &>/dev/null; then
            read -rp "  Unlock rbw vault now? [y/N] " _yn
            if [[ "$_yn" =~ ^[Yy]$ ]]; then
                retry_menu "rbw unlock" rbw unlock || true
            fi
        fi
        return 0
    fi
    [[ -n "${FORCE_SETUP:-}" && -n "$existing_email" ]] && \
        info "FORCE_SETUP=1 — re-running rbw setup despite existing config"

    read -rp "  Configure rbw now? [Y/n] " _yn
    if [[ "$_yn" =~ ^[Nn]$ ]]; then
        warn "Skipped rbw setup."; SKIPPED_BW=1; return 0
    fi

    local env_file="$HOME/.config/dotfiles/local.env" vaultwarden_url="" vaultwarden_email=""
    if [[ -f "$env_file" ]]; then
        # shellcheck disable=SC1090
        source "$env_file"
        vaultwarden_url="${VAULTWARDEN_URL:-}"; vaultwarden_email="${VAULTWARDEN_EMAIL:-}"
    fi
    if [[ -z "$vaultwarden_url" ]]; then
        echo "  [1] Self-hosted Vaultwarden (enter URL)"
        echo "  [2] Bitwarden Cloud (https://vault.bitwarden.com)"
        read -rp "  Choice [1/2]: " _choice
        case "$_choice" in
            1) read -rp "  Vaultwarden server URL: " vaultwarden_url ;;
            2) vaultwarden_url="https://vault.bitwarden.com" ;;
            *) warn "Invalid choice — skipping rbw setup"; SKIPPED_BW=1; return 0 ;;
        esac
    else
        ok "Using cached Vaultwarden URL: $vaultwarden_url"
    fi
    [[ -z "$vaultwarden_email" ]] && read -rp "  Email: " vaultwarden_email

    rbw config set email "$vaultwarden_email"
    rbw config set base_url "$vaultwarden_url"
    rbw config set pinentry pinentry-curses
    ok "rbw config written"

    mkdir -p "$(dirname "$env_file")"
    { grep -v '^VAULTWARDEN_' "$env_file" 2>/dev/null || true
      echo "VAULTWARDEN_URL=$vaultwarden_url"
      echo "VAULTWARDEN_EMAIL=$vaultwarden_email"; } > "$env_file.tmp" && mv "$env_file.tmp" "$env_file"

    info "Logging in to $vaultwarden_url — pinentry will prompt for master password..."
    if retry_menu "rbw login" rbw login; then
        ok "rbw logged in"
        retry_menu "rbw unlock" rbw unlock && ok "rbw unlocked"
        rbw sync 2>/dev/null || true
    else
        warn "rbw login skipped — retry later with: rbw login"; SKIPPED_BW=1
    fi
}

section_header "$_bw_step" "${SECTION_TITLES[$_bw_step - 1]}" \
    "Logs in and unlocks the Bitwarden/Vaultwarden CLI for secret fetching during install." \
    "Vaultwarden URL, email, master password (via prompts)." \
    "Already unlocked, or prefer to set up vault credentials manually."

SKIPPED_BW=0
setup_rbw   # no-op on Mac (PLATFORM check + no rbw binary)
setup_bw    # no-op on Linux (PLATFORM check)

# ── Atuin history sync (macOS = 8, Linux = 7) ────────────────────────────────
[[ "$PLATFORM" == "macos" ]] && _atuin_step=8 || _atuin_step=7
section_header "$_atuin_step" "${SECTION_TITLES[$_atuin_step - 1]}" \
    "Registers or logs in to Atuin for encrypted cross-device shell history sync." \
    "Server choice, account choice (register/login), and credentials." \
    "Already logged in — skips automatically. Choose [3] to skip."

setup_atuin() {
    command -v atuin >/dev/null 2>&1 || return 0

    if atuin status 2>/dev/null | grep -qE 'Logged in|Username:'; then
        if [[ -z "${FORCE_SETUP:-}" ]]; then
            ok "Atuin already configured"; return 0
        fi
        info "FORCE_SETUP=1 — re-running Atuin setup despite existing login"
    fi

    echo "  [1] Self-hosted (enter URL)  [2] Atuin Cloud  [3] Skip"
    read -rp "  Server choice [1/2/3]: " _atuin_server_choice

    local atuin_url=""
    case "${_atuin_server_choice}" in
        1)
            read -rp "  Atuin server URL (e.g. https://atuin.example.com): " atuin_url
            [[ -z "$atuin_url" ]] && { warn "No URL entered — skipping Atuin setup"; SKIPPED_ATUIN=1; return 0; }
            ;;
        2) atuin_url="https://api.atuin.sh" ;;
        *) warn "Skipped Atuin setup. Run 'atuin register' or 'atuin login' manually."; SKIPPED_ATUIN=1; return 0 ;;
    esac

    # Write URL into atuin config.
    # IMPORTANT: write to temp + mv, NOT direct redirect. If the destination
    # is a stale symlink pointing back at the template (legacy state from
    # pre-4ae7cde installs), shell truncates the template before sed reads
    # — corrupting both files. Lesson learned the hard way.
    mkdir -p "$HOME/.config/atuin"
    local _atuin_dest="$HOME/.config/atuin/config.toml"
    if [[ -L "$_atuin_dest" ]]; then
        info "Removing stale symlink at $_atuin_dest (legacy from pre-4ae7cde install.sh)"
        rm -f "$_atuin_dest"
    fi
    local _atuin_tmp
    _atuin_tmp=$(mktemp "$HOME/.config/atuin/config.toml.XXXXXX")
    sed "s|{{ATUIN_SYNC_ADDRESS}}|$atuin_url|g" "$SCRIPT_DIR/atuin/config.toml" > "$_atuin_tmp"
    if [[ ! -s "$_atuin_tmp" ]]; then
        warn "Generated atuin config is empty — template at $SCRIPT_DIR/atuin/config.toml may be corrupted"
        rm -f "$_atuin_tmp"; return 1
    fi
    mv -f "$_atuin_tmp" "$_atuin_dest"
    ok "Atuin config written with server: $atuin_url"

    mkdir -p "$HOME/.config/dotfiles"
    echo "ATUIN_SYNC_ADDRESS=$atuin_url" >> "$HOME/.config/dotfiles/local.env"

    echo "  [1] Register new account  [2] Log in (needs key)  [3] Skip"
    read -rp "  Auth choice [1/2/3]: " _atuin_auth_choice

    case "${_atuin_auth_choice}" in
        1)
            read -rp "  Username: " _u
            read -rp "  Email: " _e

            local _p="" _store_in_vault=0
            if [[ "$PLATFORM" == "macos" ]] && command -v bw >/dev/null 2>&1 && [[ -n "${BW_SESSION:-}" ]]; then
                info "Auto-generating Atuin password via bw..."
                _p=$(bw generate --length 40 --uppercase --lowercase --number --special 2>/dev/null || true)
                if [[ -n "$_p" ]]; then
                    _store_in_vault=1
                    local _item_json
                    _item_json=$(bw get template item | jq \
                        --arg n "atuin" --arg u "$_u" --arg p "$_p" \
                        '.name=$n | .type=1 | .login.username=$u | .login.password=$p | .login.uris=[]')
                    if echo "$_item_json" | bw encode | bw create item >/dev/null 2>&1; then
                        bw sync >/dev/null 2>&1 || true
                        ok "Password generated and saved to vault as 'atuin'"
                    else
                        warn "bw create item failed — password generated but not stored"
                        _store_in_vault=0
                    fi
                fi
            elif command -v rbw >/dev/null 2>&1 && rbw unlocked &>/dev/null; then
                info "Auto-generating Atuin password via rbw..."
                # rbw generate <LEN> <NAME> <USER> — generates password, saves to vault, prints to stdout
                _p=$(rbw generate 40 atuin "$_u" 2>/dev/null || true)
                [[ -n "$_p" ]] && _store_in_vault=1 && ok "Password generated and saved to vault as 'atuin'"
            fi
            if [[ -z "$_p" ]]; then
                warn "Auto-generation unavailable — enter password manually"
                read -rsp "  Password: " _p; echo
            fi

            retry_menu "atuin register" atuin register -u "$_u" -e "$_e" -p "$_p"

            info "Fetching Atuin encryption key..."
            local _key; _key=$(atuin key)

            if (( _store_in_vault )); then
                if [[ "$PLATFORM" == "macos" ]] && command -v bw >/dev/null 2>&1 && [[ -n "${BW_SESSION:-}" ]]; then
                    info "Storing encryption key in Vaultwarden as 'atuin-key'..."
                    local _key_json
                    _key_json=$(bw get template item | jq \
                        --arg n "atuin-key" --arg p "$_key" \
                        '.name=$n | .type=1 | .login.password=$p | .login.uris=[]')
                    if echo "$_key_json" | bw encode | bw create item >/dev/null 2>&1; then
                        bw sync >/dev/null 2>&1 || true
                        ok "Encryption key stored in vault as 'atuin-key'"
                    else
                        warn "Couldn't auto-store atuin-key — save manually:"
                        echo ""; echo "$_key"; echo ""
                        read -rp "  Press enter when saved in Bitwarden..." _
                    fi
                else
                    info "Storing encryption key in Vaultwarden as 'atuin-key'..."
                    # rbw add opens $EDITOR with a temp file; first line becomes the password.
                    # Override EDITOR with a one-shot script that writes the key + exits.
                    local _rbw_editor; _rbw_editor=$(mktemp)
                    cat > "$_rbw_editor" <<'EOSCRIPT'
#!/bin/sh
# rbw passes the temp file path as $1; overwrite with first-line-password.
printf '%s\n' "$RBW_AUTO_VALUE" > "$1"
EOSCRIPT
                    chmod +x "$_rbw_editor"
                    if RBW_AUTO_VALUE="$_key" EDITOR="$_rbw_editor" rbw add atuin-key 2>/dev/null; then
                        rbw sync 2>/dev/null || true
                        ok "Encryption key stored in vault as 'atuin-key'"
                    else
                        warn "Couldn't auto-store atuin-key — save manually:"
                        echo ""; echo "$_key"; echo ""
                        read -rp "  Press enter when saved in Vaultwarden as 'atuin-key'..." _
                    fi
                    rm -f "$_rbw_editor"
                fi
            else
                warn "SAVE THIS ATUIN ENCRYPTION KEY — your ONLY chance to see it:"
                echo ""; echo "$_key"; echo ""
                read -rp "  Press enter when saved in a safe place..." _
            fi

            atuin import auto 2>/dev/null || true
            atuin sync 2>/dev/null || true
            ;;
        2)
            local _u="" _p="" _k=""
            if [[ "$PLATFORM" == "macos" ]] && command -v bw >/dev/null 2>&1 && [[ -n "${BW_SESSION:-}" ]]; then
                info "Pulling Atuin credentials from Bitwarden..."
                bw sync >/dev/null 2>&1 || true
                _u=$(bw get username atuin 2>/dev/null || true)
                _p=$(bw get password atuin 2>/dev/null || true)
                _k=$(bw get password atuin-key 2>/dev/null || true)
            elif command -v rbw >/dev/null 2>&1 && rbw unlocked &>/dev/null; then
                info "Pulling Atuin credentials from Vaultwarden via rbw..."
                _u=$(rbw get --field username atuin 2>/dev/null || true)
                _p=$(rbw get atuin 2>/dev/null || true)
                _k=$(rbw get atuin-key 2>/dev/null || true)
            fi
            if [[ -z "$_u" || -z "$_p" || -z "$_k" ]]; then
                warn "Auto-pull unavailable or items missing — enter manually"
                read -rp "  Username: " _u
                read -rsp "  Password: " _p; echo
                read -rsp "  Encryption key: " _k; echo
            else
                ok "Retrieved atuin credentials from vault ($_u)"
            fi
            retry_menu "atuin login" atuin login -u "$_u" -p "$_p" -k "$_k"
            atuin import auto 2>/dev/null || true
            atuin sync 2>/dev/null || true
            ;;
        *) warn "Skipped Atuin auth. Run 'atuin register' or 'atuin login' manually."; SKIPPED_ATUIN=1 ;;
    esac
}

SKIPPED_ATUIN=0
setup_atuin

# ── Post-flight validation (macOS = 9, Linux = 8) ────────────────────────────
[[ "$PLATFORM" == "macos" ]] && _pf_step=9 || _pf_step=8
section_header "$_pf_step" "${SECTION_TITLES[$_pf_step - 1]}" \
    "Verifies symlinks, PATH commands, service state, and vault items." \
    "Nothing — fully automated." \
    "n/a — always runs."

_pf_failures=0
_chk() {
    # _chk <label> <severity:ok|warn|fail> <test-cmd...>
    local label="$1" sev="$2"; shift 2
    if "$@" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} ${label}"
    else
        case "$sev" in
            warn) echo -e "  ${YELLOW}⚠${NC} ${label}" ;;
            fail) echo -e "  ${RED}✗${NC} ${label}"; (( _pf_failures++ )) || true ;;
        esac
    fi
}

info "Checking symlinks..."
_chk "$HOME/.zshrc"              fail test -L "$HOME/.zshrc"
_chk "$HOME/.tmux.conf"          fail test -L "$HOME/.tmux.conf"
_chk "$HOME/.gitconfig"          fail test -L "$HOME/.gitconfig"
_chk "$HOME/.config/starship.toml" fail test -L "$HOME/.config/starship.toml"
info "Checking commands on PATH..."
_chk "atuin"    fail command -v atuin
_chk "starship" fail command -v starship
_chk "delta"    fail command -v delta
_chk "gh"       fail command -v gh
_chk "nvm dir"  fail test -d "$HOME/.nvm"
if [[ "$PLATFORM" == "macos" ]]; then _chk "bw"  warn command -v bw
else                                   _chk "rbw" warn command -v rbw; fi
info "Checking service state..."
_chk "gh auth status" warn gh auth status
if [[ "$PLATFORM" == "macos" ]]; then
    _bw_st=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unknown")
    if [[ "$_bw_st" == "unlocked" ]]; then echo -e "  ${GREEN}✓${NC} bw vault unlocked"
    elif [[ "$SKIPPED_BW" == "1" ]];  then echo -e "  ${YELLOW}⚠${NC} bw vault — skipped by user"
    else echo -e "  ${YELLOW}⚠${NC} bw vault locked (run: export BW_SESSION=\$(bw unlock --raw))"; fi
else
    if rbw unlocked &>/dev/null;      then echo -e "  ${GREEN}✓${NC} rbw vault unlocked"
    elif [[ "$SKIPPED_BW" == "1" ]];  then echo -e "  ${YELLOW}⚠${NC} rbw vault — skipped by user"
    else echo -e "  ${YELLOW}⚠${NC} rbw vault locked (run: rbw unlock)"; fi
fi
if [[ "$SKIPPED_ATUIN" == "1" ]]; then echo -e "  ${YELLOW}⚠${NC} atuin — skipped by user"
else _chk "atuin status" warn atuin status; fi

info "Checking vault items..."
if [[ "$PLATFORM" == "macos" ]] && [[ -n "${BW_SESSION:-}" ]]; then
    _chk "vault item 'atuin'"     warn bw get item atuin
    _chk "vault item 'atuin-key'" warn bw get item atuin-key
elif command -v rbw &>/dev/null && rbw unlocked &>/dev/null; then
    _chk "vault item 'atuin'"     warn rbw get atuin
    _chk "vault item 'atuin-key'" warn rbw get atuin-key
else
    echo -e "  ${YELLOW}⚠${NC} vault items — vault not unlocked, skipping check"
fi

# Probe Full Disk Access for Mail (macOS only). Using com.apple.mail as the
# sentinel — it's reliable and safe to read without elevated privileges.
# Direct defaults write fails silently without FDA (commit 0945791).
if [[ "$PLATFORM" == "macos" ]]; then
    info "Checking Full Disk Access..."
    if defaults read com.apple.mail &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Full Disk Access granted (com.apple.mail readable)"
    else
        echo -e "  ${YELLOW}⚠${NC} Full Disk Access not granted — some defaults may not apply."
        echo "      System Settings → Privacy & Security → Full Disk Access → Terminal"
    fi
fi

# ── Validation result ──────────────────────────────
if (( _pf_failures > 0 )); then
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  Post-flight: ${_pf_failures} hard failure(s) detected${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "  Fix: broken symlink → re-run ./install.sh"
    echo "       command missing → check Step 1 output above"
    echo "       nvm missing     → source ~/.nvm/nvm.sh or new shell"
    echo "  Run FORCE_SETUP=1 ./install.sh to bypass skip guards."
    exit 0
fi

# ── Success banner — printed ONLY after all service setup + post-flight pass ─
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Installation complete! (${PLATFORM})$(printf '%*s' $((14 - ${#PLATFORM})) '')║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  Multiplexer  tmux + Catppuccin + vim keys"
echo "  Prompt       Starship Catppuccin palette"
echo "  Shell        zsh + autosuggestions + syntax highlighting"
echo "  Tools        bat eza delta zoxide nano vim"
echo "  Claude       Config, statusline, plugins"
if [[ "$PLATFORM" == "macos" ]]; then
echo "  Terminal     Ghostty with Catppuccin Mocha"
fi
echo "  Re-run prompts: FORCE_SETUP=1 ./install.sh   Runbook: docs/bitwarden-rbw-setup.md"
echo ""
if [[ "$PLATFORM" == "macos" ]] && [[ "$HEADLESS_MODE" == "1" ]]; then
echo -e "  ${YELLOW}⚠${NC} Plug in an HDMI dummy plug (~\$5) for crisp 4K Screen Sharing."
fi

# ── Restart banner ─────────────────────────────────
echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  RESTART YOUR SHELL NOW to load the new configuration ║${NC}"
echo -e "${YELLOW}║                                                        ║${NC}"
echo -e "${YELLOW}║      exec zsh                                          ║${NC}"
echo -e "${YELLOW}║                                                        ║${NC}"
echo -e "${YELLOW}║  (or close this terminal and open a new one)           ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
