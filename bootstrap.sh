#!/usr/bin/env bash
# Mac mini bootstrap — clone dotfiles and run install.sh.
# Run on a fresh Mac mini:
#   curl -fsSL https://raw.githubusercontent.com/sebstrgg/dotfiles/main/bootstrap.sh | bash

set -euo pipefail

REPO_URL="https://github.com/sebstrgg/dotfiles.git"
TARGET="$HOME/dotfiles"

# Xcode Command Line Tools (provides git) — install if missing
if ! xcode-select -p &>/dev/null; then
    echo "→ Installing Xcode Command Line Tools (required for git)..."
    xcode-select --install
    echo ""
    echo "  A dialog has popped up. Click 'Install' and wait ~5 minutes."
    echo "  When the install finishes, re-run:"
    echo ""
    echo "    curl -fsSL https://raw.githubusercontent.com/sebstrgg/dotfiles/main/bootstrap.sh | bash"
    echo ""
    exit 0
fi

# Clone or update
if [[ -d "$TARGET/.git" ]]; then
    echo "→ dotfiles already cloned — pulling latest"
    cd "$TARGET"
    git pull --ff-only
else
    echo "→ Cloning dotfiles to $TARGET"
    git clone "$REPO_URL" "$TARGET"
    cd "$TARGET"
fi

echo ""
echo "→ Running install.sh"
echo ""
./install.sh
