#!/usr/bin/env bash
set -euo pipefail

# ── Dotfiles Installer ────────────────────────────────
# Bootstraps a macOS or Ubuntu/WSL2 machine with the full terminal environment.
# Safe to run multiple times — backs up existing configs, never overwrites silently.

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

confirm() {
    read -rp "$1 [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Back up and symlink a file.
# Usage: link_config <source> <destination>
link_config() {
    local src="$1"
    local dst="$2"

    mkdir -p "$(dirname "$dst")"

    if [[ -e "$dst" && ! -L "$dst" ]]; then
        local backup="${dst}.backup.$(date +%s)"
        warn "Existing file at $dst — backing up to $backup"
        cp -r "$dst" "$backup"
    fi

    ln -sf "$src" "$dst"
    ok "$(basename "$dst") → $dst"
}

# Copy a file (for theme files that shouldn't be symlinks).
# Usage: copy_config <source> <destination>
copy_config() {
    local src="$1"
    local dst="$2"

    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
    ok "$(basename "$dst") → $dst (copied)"
}

# ── Platform Detection ───────────────────────────────
OS="$(uname -s)"
case "$OS" in
    Darwin) PLATFORM="macos" ;;
    Linux)  PLATFORM="linux" ;;
    *)      error "Unsupported OS: $OS"; exit 1 ;;
esac

# ── Headless Mac mini detection ───────────────────────
HEADLESS_MODE=0
if [[ "$PLATFORM" == "macos" ]]; then
    echo ""
    echo "────────────────────────────────────────────────────────────"
    echo "Is this a headless Mac mini?"
    echo ""
    echo "  Headless = always on, no display attached, accessed only"
    echo "  via Apple Screen Sharing or VNC from another machine."
    echo ""
    echo "  Answering YES will:"
    echo "    • Disable system/display/disk sleep (pmset always-on)"
    echo "    • Enable Wake-on-LAN + auto-restart after power failure"
    echo "    • Tune the Screen Sharing VNC fallback for max quality"
    echo "    • Print HDMI dummy plug reminder in the final checklist"
    echo ""
    echo "  Answer NO if this is a laptop, a work/managed Mac, or a"
    echo "  regular desktop with a display attached — you don't want"
    echo "  to disable sleep on those."
    echo "────────────────────────────────────────────────────────────"
    read -rp "Configure as headless Mac mini? [y/N] " _reply
    case "$_reply" in
        [Yy]*) HEADLESS_MODE=1; ok "Headless Mac mini mode enabled" ;;
        *)     HEADLESS_MODE=0; info "Skipping headless-specific steps" ;;
    esac
    echo ""
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Dotfiles Installer                      ║${NC}"
echo -e "${BLUE}║  Catppuccin Mocha | Ghostty + tmux       ║${NC}"
echo -e "${BLUE}║  Platform: ${PLATFORM}$(printf '%*s' $((27 - ${#PLATFORM})) '')║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Step 1: Install packages ────────────────────────
if [[ "$PLATFORM" == "macos" ]]; then
    info "Checking for Homebrew..."
    if command -v brew &>/dev/null; then
        ok "Homebrew already installed"
    else
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
        ok "Homebrew installed"
    fi

    info "Installing packages from Brewfile..."
    brew bundle --file="$SCRIPT_DIR/Brewfile"
    ok "All packages installed"

elif [[ "$PLATFORM" == "linux" ]]; then
    info "Installing packages via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        zsh \
        tmux \
        bat \
        eza \
        fzf \
        zoxide \
        nano \
        jq \
        curl \
        git \
        build-essential \
        openssh-server \
        mosh \
        gh \
        zsh-autosuggestions \
        zsh-syntax-highlighting \
        ripgrep \
        fd-find \
        direnv \
        shellcheck
    ok "All packages installed"

    # git-delta (not in apt, install from GitHub releases)
    if ! command -v delta &>/dev/null; then
        info "Installing git-delta..."
        DELTA_VERSION="0.18.2"
        ARCH="$(dpkg --print-architecture)"
        curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_${ARCH}.deb" \
            -o /tmp/git-delta.deb
        sudo dpkg -i /tmp/git-delta.deb
        rm -f /tmp/git-delta.deb
        ok "git-delta installed"
    else
        ok "git-delta already installed"
    fi

    # Starship (not in apt, use official installer)
    if ! command -v starship &>/dev/null; then
        info "Installing Starship prompt..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
        ok "Starship installed"
    else
        ok "Starship already installed"
    fi

    # atuin (shell history sync) — not in apt, use official installer
    if ! command -v atuin &>/dev/null; then
        info "Installing atuin (shell history sync)..."
        curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
        # Installer drops binary at ~/.atuin/bin/atuin — make sure PATH picks it up.
        # (zshrc already sources this via $HOME/.atuin/bin if we ever need it; for now
        # the installer edits shell rc files, which we then overwrite — so symlink
        # the binary into ~/.local/bin for PATH stability.)
        if [[ -x "$HOME/.atuin/bin/atuin" ]]; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$HOME/.atuin/bin/atuin" "$HOME/.local/bin/atuin"
        fi
        ok "atuin installed"
        # Strip the atuin installer's self-added shell rc modification — we handle
        # PATH via our own symlink to ~/.local/bin and load atuin via our own
        # `eval "$(atuin init zsh)"` line in zshrc. The installer's line is redundant
        # and silently drifts our tracked .zshrc (since it's symlinked into place).
        for _rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
            if [[ -f "$_rc" ]] && grep -qF '.atuin/bin/env' "$_rc"; then
                sed -i '/\.atuin\/bin\/env/d' "$_rc"
                info "Removed atuin installer's auto-appended line from $_rc"
            fi
        done
    else
        ok "atuin already installed"
    fi

    # rbw (Bitwarden CLI with built-in SSH agent) + pinentry prerequisite
    if ! dpkg -l | grep -q '^ii  pinentry-curses '; then
        info "Installing pinentry-curses (required by rbw)..."
        sudo apt-get install -y -qq pinentry-curses
        ok "pinentry-curses installed"
    fi

    if ! command -v rbw &>/dev/null; then
        info "Installing rbw (Bitwarden CLI)..."
        # Path 1: apt (Debian testing+)
        if apt-cache show rbw >/dev/null 2>&1; then
            sudo apt-get install -y -qq rbw
        else
            # Path 2: cargo install. Auto-install Rust toolchain if missing.
            if ! command -v cargo &>/dev/null; then
                info "Installing Rust toolchain (required to build rbw)..."
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
                    | sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path
                # Make cargo available in THIS shell session
                if [[ -f "$HOME/.cargo/env" ]]; then
                    # shellcheck disable=SC1091
                    source "$HOME/.cargo/env"
                fi
                ok "Rust toolchain installed"
            fi
            info "Building rbw via cargo (2-5 minutes)..."
            cargo install --locked rbw
        fi
        # Symlink to ~/.local/bin for PATH stability (matches atuin handling)
        if [[ -x "$HOME/.cargo/bin/rbw" ]]; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$HOME/.cargo/bin/rbw" "$HOME/.local/bin/rbw"
            ln -sf "$HOME/.cargo/bin/rbw-agent" "$HOME/.local/bin/rbw-agent" 2>/dev/null || true
        fi
        ok "rbw installed"
    else
        ok "rbw already installed"
    fi

    # bat → batcat alias (Ubuntu may install bat as batcat)
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(which batcat)" "$HOME/.local/bin/bat"
        ok "bat alias created (batcat → bat)"
    fi

    # fd-find → fd alias (Ubuntu names the binary fdfind)
    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
        ok "fd alias created (fdfind → fd)"
    fi

    # Set zsh as default shell
    if [[ "$SHELL" != *"zsh"* ]]; then
        info "Setting zsh as default shell..."
        chsh -s "$(which zsh)"
        ok "Default shell set to zsh"
    else
        ok "zsh is already default shell"
    fi
fi

# ── Step 1c: macOS app preference restore ─────────────
if [[ "$PLATFORM" == "macos" ]]; then
    info "Restoring macOS app preferences..."
    MAC_APPS="$SCRIPT_DIR/mac-apps"

    if [[ -d "$MAC_APPS/plists" ]]; then
        for plist in "$MAC_APPS/plists"/*.plist; do
            [[ -f "$plist" ]] || continue
            domain=$(basename "$plist" .plist)
            defaults import "$domain" "$plist"
            ok "Restored prefs: $domain"
        done
        killall cfprefsd 2>/dev/null || true   # force macOS to reload prefs immediately
    fi

    # LinearMouse — JSON config
    LM_JSON="$MAC_APPS/linearmouse/linearmouse.json"
    if [[ -f "$LM_JSON" ]]; then
        mkdir -p "$HOME/Library/Application Support/LinearMouse"
        cp "$LM_JSON" "$HOME/Library/Application Support/LinearMouse/linearmouse.json"
        ok "Restored LinearMouse JSON"
    fi

    # Alfred — point Alfred at the committed sync folder
    # (Alfred will read workflows/snippets directly from the repo path,
    #  so future changes show up as `git diff` on the dotfiles repo.)
    if [[ -d "$MAC_APPS/alfred" ]]; then
        defaults write com.runningwithcrayons.Alfred-Preferences syncfolder -string "$MAC_APPS/alfred"
        ok "Alfred sync folder → $MAC_APPS/alfred"
    fi
fi

# ── Step 1d: macOS hotkey remaps, defaults, pmset, screensharing ─────
if [[ "$PLATFORM" == "macos" ]]; then
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

# ── Step 2: nvm (both platforms) ─────────────────────
if [[ ! -d "$HOME/.nvm" ]]; then
    info "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    nvm install --lts
    ok "nvm + Node.js LTS installed"
else
    ok "nvm already installed"
fi

# ── Step 3: Symlink configs ─────────────────────────
echo ""
info "Symlinking configuration files..."

# Shared configs (both platforms)
link_config "$SCRIPT_DIR/tmux/tmux.conf"         "$HOME/.tmux.conf"
link_config "$SCRIPT_DIR/starship/starship.toml"  "$HOME/.config/starship.toml"
link_config "$SCRIPT_DIR/zsh/.zshrc"              "$HOME/.zshrc"
link_config "$SCRIPT_DIR/git/.gitconfig"          "$HOME/.gitconfig"
link_config "$SCRIPT_DIR/bat/config"              "$HOME/.config/bat/config"
link_config "$SCRIPT_DIR/nano/.nanorc"            "$HOME/.nanorc"
link_config "$SCRIPT_DIR/vim/.vimrc"              "$HOME/.vimrc"
# atuin/config.toml is NOT symlinked here — setup_atuin() writes it via sed substitution

# macOS-only configs
if [[ "$PLATFORM" == "macos" ]]; then
    link_config "$SCRIPT_DIR/ghostty/config"      "$HOME/.config/ghostty/config"
fi

# ── Step 4: Copy theme files ────────────────────────
echo ""
info "Installing Catppuccin themes..."

copy_config "$SCRIPT_DIR/bat/themes/Catppuccin Mocha.tmTheme" "$HOME/.config/bat/themes/Catppuccin Mocha.tmTheme"
copy_config "$SCRIPT_DIR/git/catppuccin.gitconfig"             "$HOME/.config/git/catppuccin.gitconfig"

mkdir -p "$HOME/.config/zsh"
copy_config "$SCRIPT_DIR/zsh-syntax-highlighting/catppuccin_mocha-zsh-syntax-highlighting.zsh" \
            "$HOME/.config/zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh"

# Rebuild bat theme cache
if command -v bat &>/dev/null; then
    info "Building bat theme cache..."
    bat cache --build &>/dev/null
    ok "bat themes cached"
elif command -v batcat &>/dev/null; then
    # On Ubuntu, bat is installed as batcat
    info "Building bat theme cache..."
    batcat cache --build &>/dev/null
    ok "bat themes cached"
fi

# ── Step 5: tmux setup ──────────────────────────────
echo ""
info "Setting up tmux..."

# Copy cheatsheet and session bootstrap
mkdir -p "$HOME/.tmux"
cp "$SCRIPT_DIR/tmux/cheatsheet.sh" "$HOME/.tmux/cheatsheet.sh"
chmod +x "$HOME/.tmux/cheatsheet.sh"
ok "Cheat sheet installed"

cp "$SCRIPT_DIR/tmux/session-dev.sh" "$HOME/.tmux/session-dev.sh"
chmod +x "$HOME/.tmux/session-dev.sh"
ok "Session bootstrap script installed"

# Install TPM (Tmux Plugin Manager)
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ -d "$TPM_DIR" ]]; then
    ok "TPM already installed"
else
    info "Installing TPM..."
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    ok "TPM installed"
fi

# ── Step 6: Claude Code config ──────────────────────
echo ""
info "Setting up Claude Code configuration..."

mkdir -p "$HOME/.claude/rules"

link_config "$SCRIPT_DIR/claude/settings.json"  "$HOME/.claude/settings.json"
link_config "$SCRIPT_DIR/claude/statusline.sh"  "$HOME/.claude/statusline.sh"
chmod +x "$HOME/.claude/statusline.sh"

# Symlink each rule file individually (not the directory, to preserve any local rules)
for rule in "$SCRIPT_DIR"/claude/rules/*.md; do
    if [[ -f "$rule" ]]; then
        link_config "$rule" "$HOME/.claude/rules/$(basename "$rule")"
    fi
done
ok "Claude Code config linked"

# ── Step 7: Linux-specific services ─────────────────
if [[ "$PLATFORM" == "linux" ]]; then
    echo ""
    info "Configuring Linux services..."

    # Docker Engine setup (via official apt repo, not get.docker.com which nags about Desktop)
    if ! command -v docker &>/dev/null; then
        if confirm "Install Docker Engine?"; then
            info "Installing Docker Engine via official apt repository..."
            sudo install -m 0755 -d /etc/apt/keyrings
            sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            sudo chmod a+r /etc/apt/keyrings/docker.asc
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

    # Reminder for manual steps
    echo ""
    warn "Manual steps remaining (see docs/wsl2-setup.md):"
    echo "  - Configure /etc/ssh/sshd_config for Tailscale-only listening"
    echo "  - Install and configure Tailscale"
    echo "  - Set up Windows Task Scheduler for WSL2 auto-start"
fi

# ── Done ─────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation complete! (${PLATFORM})${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo "  What's set up:"
echo ""
echo "    Multiplexer tmux with Catppuccin + vim keys"
echo "    Prompt      Starship with Catppuccin palette"
echo "    Shell       zsh with autosuggestions + syntax highlighting"
echo "    cat         bat (syntax highlighting, line numbers)"
echo "    ls          eza (icons, colors, tree view)"
echo "    git diff    delta (side-by-side, Catppuccin colors)"
echo "    cd          zoxide (learns your directories)"
echo "    Editors     nano + vim with syntax highlighting"
echo "    Claude      Config, statusline, plugins"
if [[ "$PLATFORM" == "macos" ]]; then
echo "    Terminal    Ghostty with Catppuccin Mocha"
echo "    Markdown    glow (render in terminal)"
echo "    Remote      mosh client for connecting to VMs"
fi
echo ""
echo "  Next steps:"
echo ""
if [[ "$PLATFORM" == "macos" ]] && [[ "$HEADLESS_MODE" == "1" ]]; then
echo "  ⚠ If you haven't already: plug in an HDMI dummy plug"
echo "    (~\$5 on Amazon). Forces a 4K framebuffer so Screen"
echo "    Sharing is crisp. Single biggest remote-desktop win."
echo ""
fi
echo ""
echo "  Atuin history sync:    configured interactively above (or skipped)"
echo "  Runbook:               docs/bitwarden-rbw-setup.md"
echo ""
echo "  Bitwarden + SSH key management:"
echo ""
if [[ "$PLATFORM" == "macos" ]]; then
echo "    macOS uses Bitwarden Desktop's built-in SSH agent:"
echo "      1. Open Bitwarden Desktop and log in"
echo "      2. Settings → Security → enable 'SSH Agent'"
echo "      3. Settings → Security → 'Unlock with Touch ID' (laptop)"
echo "         or 'Never lock' (Mac mini, always-on)"
echo "      4. System Settings → Login Items → ensure Bitwarden starts at login"
echo "      5. Restart terminal — SSH_AUTH_SOCK now points at Bitwarden agent"
echo ""
echo "    Full setup + key migration runbook: docs/bitwarden-rbw-setup.md"
else
echo "    Linux / WSL uses rbw with built-in SSH agent:"
echo "      rbw config set email <your-vaultwarden-email>"
echo "      rbw config set base_url <your-vaultwarden-url>"
echo "      rbw config set pinentry pinentry-curses"
echo "      rbw login           # enter master password via pinentry"
echo "      rbw unlock          # starts the SSH agent"
echo "      ssh-add -L          # verify vault SSH keys are visible"
echo ""
echo "    Full migration + usage runbook: docs/bitwarden-rbw-setup.md"
fi
echo ""
if [[ "$PLATFORM" == "macos" ]]; then
echo "  1. Install Element X from the Mac App Store"
echo "     Open App Store → search \"Element X\" → click Get (id 1631335820)."
echo "     Free app, ~30 seconds. Then sign in (next step)."
echo "  2. Open a new terminal (or restart your shell)"
echo "  3. Press Ctrl+a then I (capital i) to install tmux plugins"
echo "  4. Press Ctrl+a then r to reload tmux config"
echo "  5. Press Ctrl+a then ? for the cheat sheet"
else
echo "  1. Open a new terminal (or restart your shell)"
echo "  2. Press Ctrl+a then I (capital i) to install tmux plugins"
echo "  3. Press Ctrl+a then r to reload tmux config"
echo "  4. Press Ctrl+a then ? for the cheat sheet"
fi
echo ""

# ── Step 8: GitHub CLI auth ─────────────────────────
if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null; then
        ok "GitHub CLI already authenticated"
    else
        echo ""
        if confirm "Authenticate with GitHub CLI? (opens browser)"; then
            gh auth login
        else
            warn "Skipped GitHub CLI auth — run 'gh auth login' later"
        fi
    fi
fi

# ── Step 9a: rbw configuration ──────────────────────
# Interactive rbw configuration — runs on first use, idempotent after.
setup_rbw() {
    command -v rbw >/dev/null 2>&1 || return 0

    # Detect already-configured
    local existing_email
    existing_email=$(rbw config show 2>/dev/null | grep -oP '(?<="email": ")[^"]*')
    if [[ -n "$existing_email" && "$existing_email" != "null" ]]; then
        ok "rbw already configured (email: $existing_email)"
        # Still offer to unlock if locked
        if ! rbw unlocked &>/dev/null; then
            read -rp "Unlock rbw vault now? [y/N] " _yn
            [[ "$_yn" =~ ^[Yy]$ ]] && rbw unlock
        fi
        return 0
    fi

    echo ""
    echo "────────────────────────────────────────────────────────────"
    echo "Bitwarden / Vaultwarden (rbw) — configure now?"
    echo "  Needed for: SSH agent, secret fetching (bws/bwu/bwn), Atuin"
    echo "  credentials sync across devices."
    echo "  Skip with N to configure later via 'rbw config set' manually."
    echo "────────────────────────────────────────────────────────────"
    read -rp "Configure rbw now? [Y/n] " _yn
    if [[ "$_yn" =~ ^[Nn]$ ]]; then
        warn "Skipped rbw setup."
        return 0
    fi

    # Load cached answer if any
    local env_file="$HOME/.config/dotfiles/local.env"
    local vaultwarden_url=""
    local vaultwarden_email=""
    if [[ -f "$env_file" ]]; then
        # shellcheck disable=SC1090
        source "$env_file"
        vaultwarden_url="${VAULTWARDEN_URL:-}"
        vaultwarden_email="${VAULTWARDEN_EMAIL:-}"
    fi

    if [[ -z "$vaultwarden_url" ]]; then
        echo "  [1] Self-hosted Vaultwarden (enter URL)"
        echo "  [2] Bitwarden Cloud (https://vault.bitwarden.com)"
        read -rp "Choice [1/2]: " _choice
        case "$_choice" in
            1) read -rp "  Vaultwarden server URL: " vaultwarden_url ;;
            2) vaultwarden_url="https://vault.bitwarden.com" ;;
            *) warn "Invalid choice — skipping rbw setup"; return 0 ;;
        esac
    else
        ok "Using cached Vaultwarden URL: $vaultwarden_url"
    fi

    [[ -z "$vaultwarden_email" ]] && read -rp "  Email: " vaultwarden_email

    rbw config set email "$vaultwarden_email"
    rbw config set base_url "$vaultwarden_url"
    rbw config set pinentry pinentry-curses
    ok "rbw config written"

    # Cache for re-runs
    mkdir -p "$(dirname "$env_file")"
    {
        grep -v '^VAULTWARDEN_' "$env_file" 2>/dev/null || true
        echo "VAULTWARDEN_URL=$vaultwarden_url"
        echo "VAULTWARDEN_EMAIL=$vaultwarden_email"
    } > "$env_file.tmp" && mv "$env_file.tmp" "$env_file"

    echo ""
    info "Logging in to $vaultwarden_url — pinentry will prompt for master password..."
    if rbw login; then
        ok "rbw logged in"
        rbw unlock && ok "rbw unlocked"
        rbw sync 2>/dev/null || true
    else
        warn "rbw login failed — you can retry later with: rbw login"
    fi
}

# ── Step 9b: Interactive Atuin setup ─────────────────
# Runs once. Skips if already logged in.
setup_atuin() {
    command -v atuin >/dev/null 2>&1 || return 0

    # `atuin status` exits 0 when logged in, non-zero otherwise
    if atuin status 2>/dev/null | grep -qE 'Logged in|Username:'; then
        ok "Atuin already configured"
        return 0
    fi

    echo ""
    echo "────────────────────────────────────────────────────────────"
    echo "Atuin shell history sync — choose a server:"
    echo ""
    echo "  [1] Self-hosted (enter URL)"
    echo "  [2] Atuin Cloud (https://api.atuin.sh)"
    echo "  [3] Skip — set up manually later"
    echo "────────────────────────────────────────────────────────────"
    read -rp "Choice [1/2/3]: " _atuin_server_choice

    local atuin_url=""
    case "${_atuin_server_choice}" in
        1)
            read -rp "  Atuin server URL (e.g. https://atuin.example.com): " atuin_url
            [[ -z "$atuin_url" ]] && { warn "No URL entered — skipping Atuin setup"; return 0; }
            ;;
        2) atuin_url="https://api.atuin.sh" ;;
        *) warn "Skipped Atuin setup. Run 'atuin register' or 'atuin login' manually."; return 0 ;;
    esac

    # Write the URL into the actual atuin config (template + substitution)
    mkdir -p "$HOME/.config/atuin"
    sed "s|{{ATUIN_SYNC_ADDRESS}}|$atuin_url|g" \
        "$SCRIPT_DIR/atuin/config.toml" \
        > "$HOME/.config/atuin/config.toml"
    ok "Atuin config written with server: $atuin_url"

    # Cache the answer for re-runs
    mkdir -p "$HOME/.config/dotfiles"
    echo "ATUIN_SYNC_ADDRESS=$atuin_url" >> "$HOME/.config/dotfiles/local.env"

    echo ""
    echo "  [1] Register new account (first device)"
    echo "  [2] Log in to existing account (other devices — needs encryption key)"
    echo "  [3] Skip — register/login manually"
    read -rp "Choice [1/2/3]: " _atuin_auth_choice

    case "${_atuin_auth_choice}" in
        1)
            read -rp "  Username: " _u
            read -rp "  Email: " _e

            local _p=""
            local _store_in_vault=0
            if command -v rbw >/dev/null 2>&1 && rbw unlocked &>/dev/null; then
                info "Auto-generating Atuin password via rbw..."
                # rbw generate <LEN> <NAME> <USER> — generates password, saves to vault, prints to stdout
                _p=$(rbw generate 40 atuin "$_u" 2>/dev/null || true)
                if [[ -n "$_p" ]]; then
                    _store_in_vault=1
                    ok "Password generated and saved to vault as 'atuin'"
                fi
            fi
            if [[ -z "$_p" ]]; then
                warn "rbw unavailable — enter password manually"
                read -rsp "  Password: " _p; echo
            fi

            atuin register -u "$_u" -e "$_e" -p "$_p"

            echo ""
            info "Fetching Atuin encryption key..."
            local _key
            _key=$(atuin key)
            if (( _store_in_vault )); then
                # rbw add always opens an interactive editor — cannot pipe non-interactively.
                # Instruct the user to store the key manually in Vaultwarden.
                warn "SAVE THIS ATUIN ENCRYPTION KEY in Vaultwarden as a Secure Note named 'atuin-key':"
                echo ""
                echo "$_key"
                echo ""
                warn "  Open Vaultwarden → New Item → Secure Note → Name: atuin-key → paste key above"
                read -rp "Press enter when saved in Vaultwarden..." _
                rbw sync 2>/dev/null || true
                ok "Atuin credentials stored. Run 'rbw sync' after saving the note."
            else
                warn "SAVE THIS ATUIN ENCRYPTION KEY — your ONLY chance to see it:"
                echo ""
                echo "$_key"
                echo ""
                warn "Store it in Bitwarden as a Secure Note named 'atuin-key'."
                read -rp "Press enter when saved in a safe place..." _
            fi

            atuin import auto 2>/dev/null || true
            atuin sync 2>/dev/null || true
            ;;
        2)
            local _u="" _p="" _k=""
            if command -v rbw >/dev/null 2>&1 && rbw unlocked &>/dev/null; then
                info "Pulling Atuin credentials from Vaultwarden..."
                _u=$(rbw get --field username atuin 2>/dev/null || true)
                _p=$(rbw get atuin 2>/dev/null || true)
                _k=$(rbw get atuin-key 2>/dev/null || true)
            fi

            if [[ -z "$_u" || -z "$_p" || -z "$_k" ]]; then
                warn "rbw unavailable or items missing — enter manually"
                read -rp "  Username: " _u
                read -rsp "  Password: " _p; echo
                read -rsp "  Encryption key: " _k; echo
            else
                ok "Retrieved Atuin credentials from vault ($_u)"
            fi

            atuin login -u "$_u" -p "$_p" -k "$_k"
            atuin import auto 2>/dev/null || true
            atuin sync 2>/dev/null || true
            ;;
        *) warn "Skipped Atuin auth. Run 'atuin register' or 'atuin login' manually." ;;
    esac
}

setup_rbw
setup_atuin

echo ""
echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  RESTART YOUR SHELL NOW to load the new configuration ║${NC}"
echo -e "${YELLOW}║                                                        ║${NC}"
echo -e "${YELLOW}║      exec zsh                                          ║${NC}"
echo -e "${YELLOW}║                                                        ║${NC}"
echo -e "${YELLOW}║  (or close this terminal and open a new one)           ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
