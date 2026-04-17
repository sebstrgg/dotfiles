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
        zsh-syntax-highlighting
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

    # bat → batcat alias (Ubuntu may install bat as batcat)
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(which batcat)" "$HOME/.local/bin/bat"
        ok "bat alias created (batcat → bat)"
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

# ── Step 1b: Mac App Store apps ──────────────────────
if [[ "$PLATFORM" == "macos" ]]; then
    info "Installing Mac App Store apps..."
    if command -v mas &>/dev/null; then
        mas install 1631335820  # Element X — idempotent; no-op if installed
        ok "MAS apps installed"
    else
        warn "mas CLI not found — Element X install skipped"
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

# ── Step 1d: macOS hotkey remaps, defaults, pmset ─────
if [[ "$PLATFORM" == "macos" ]]; then
    info "Applying macOS hotkey remaps..."
    bash "$SCRIPT_DIR/mac-apps/hotkeys/symbolichotkeys.sh"
    ok "Hotkey remaps applied"

    info "Applying macOS defaults..."
    bash "$SCRIPT_DIR/mac-apps/defaults/macos-defaults.sh"
    ok "macOS defaults applied"

    info "Configuring always-on power settings..."
    bash "$SCRIPT_DIR/mac-apps/pmset/always-on.sh"
    ok "Power settings applied"

    info "Tuning Screen Sharing (VNC fallback path)..."
    bash "$SCRIPT_DIR/mac-apps/screensharing/tune.sh"
    ok "Screen Sharing tuned"
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
echo "  1. Open a new terminal (or restart your shell)"
echo "  2. Press Ctrl+a then I (capital i) to install tmux plugins"
echo "  3. Press Ctrl+a then r to reload tmux config"
echo "  4. Press Ctrl+a then ? for the cheat sheet"
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
