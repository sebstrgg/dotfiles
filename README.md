# dotfiles

Personal terminal environment for macOS — Ghostty, tmux, and modern CLI tools, all themed with Catppuccin Mocha.

## What You Get

| Tool | Replaces | What it does |
|------|----------|-------------|
| [Ghostty](https://ghostty.org) | Terminal.app | GPU-accelerated terminal emulator |
| [tmux](https://github.com/tmux/tmux) | — | Terminal multiplexer with session persistence |
| [Starship](https://starship.rs) | default prompt | Minimal prompt showing directory, git, command duration |
| [eza](https://eza.rocks) | `ls` | File listing with icons and colors |
| [bat](https://github.com/sharkdp/bat) | `cat` | Syntax highlighting and line numbers |
| [delta](https://dandavison.github.io/delta/) | `git diff` | Beautiful side-by-side diffs |
| [fzf](https://junegunn.github.io/fzf/) | Ctrl+T | Fuzzy finder for files and more (Ctrl+R taken by atuin) |
| [atuin](https://atuin.sh) | `Ctrl+R` | Encrypted shell history sync across all machines (self-hosted or Atuin Cloud) |
| [Bitwarden Desktop](https://bitwarden.com/download/) / [rbw](https://github.com/doy/rbw) | ssh-agent / secret store | SSH keys + passwords synced from self-hosted Vaultwarden. Built-in SSH agent on both macOS (Desktop app) and Linux (rbw). |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd` | Smart directory jumping that learns your habits |
| [glow](https://github.com/charmbracelet/glow) | — | Render markdown beautifully in the terminal |
| [nano](https://www.nano-editor.org) | macOS nano | Modern nano with syntax highlighting |
| [gh](https://cli.github.com) | — | GitHub CLI |

All visual tools use the [Catppuccin Mocha](https://github.com/catppuccin/catppuccin) color scheme.

## Install

```bash
git clone https://github.com/sebstrgg/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The install script:
1. Installs Homebrew (if missing)
2. Installs all packages from the Brewfile
3. Symlinks all config files to their expected locations
4. Installs Catppuccin themes for bat, delta, and zsh-syntax-highlighting
5. Sets up TPM (tmux plugin manager)
6. Optionally authenticates with GitHub CLI

**After install**, open Ghostty and press `Ctrl+a I` (capital i) to install tmux plugins, then `Ctrl+a r` to reload.

### Bitwarden + rbw

SSH keys and secrets sync from self-hosted Vaultwarden (or Bitwarden cloud).
Full setup + migration runbook: [docs/bitwarden-rbw-setup.md](docs/bitwarden-rbw-setup.md).

### Atuin — shell history sync

Atuin syncs encrypted shell history across all machines. The installer prompts for your server URL (self-hosted or Atuin Cloud) and handles registration interactively.

**First device** (create the account):
```bash
atuin register -u <username> -e <email>
atuin key      # PRINT AND SAVE — needed on every other device
atuin sync
```

**Additional devices** (join the existing account):
```bash
atuin login -u <username> -k <key-from-first-device>
atuin import auto   # import local shell history into Atuin
atuin sync
```

`Ctrl+R` searches across all machines. Up-arrow stays session-local (configured in `atuin/config.toml`).

## Post-Install: What Changed

These commands now work differently (better):

| You type | What happens now |
|----------|-----------------|
| `cat file.py` | Syntax-highlighted output with line numbers (bat) |
| `ls` | Colored listing with file type icons (eza) |
| `ll` | Detailed listing with icons (eza -la) |
| `lt` | Tree view, 2 levels deep (eza --tree) |
| `git diff` | Side-by-side diff with Catppuccin colors (delta) |
| `git log -p` | Syntax-highlighted patches (delta) |
| `cd projects` | Jumps to your most-visited matching directory (zoxide) |
| `Ctrl+R` | Fuzzy search through shell history, synced across machines (atuin) |
| `Ctrl+T` | Fuzzy search for files (fzf) |
| `glow README.md` | Rendered markdown in the terminal |
| `nano file.py` | Syntax-highlighted editing |
| `catp file.py` | Like cat but with scrollable pager |
| `gs`, `gl`, `gd` | `git status`, `git log`, `git diff` shorthand |
| `..`, `...`, `....` | Move up 1/2/3 directory levels |
| `ta`, `tn`, `tls`, `tk` | tmux attach / new / list / kill-session |

## Directory Structure

```
dotfiles/
├── ghostty/config              Ghostty terminal config
├── tmux/
│   ├── tmux.conf               tmux config (prefix: Ctrl+a)
│   └── cheatsheet.sh           Ctrl+a ? cheat sheet popup
├── starship/starship.toml      Starship prompt config
├── zsh/.zshrc                  Shell config (aliases, plugins, tool init)
├── zsh/.zshrc.local.example    Template for machine-local overrides (gitignored)
├── git/
│   ├── .gitconfig              Git config (delta, identity)
│   └── catppuccin.gitconfig    Catppuccin Mocha theme for delta
├── bat/
│   ├── config                  bat config (theme)
│   └── themes/                 Catppuccin Mocha .tmTheme
├── nano/.nanorc                nano config
├── vim/.vimrc                  vim config
├── zsh-syntax-highlighting/    Catppuccin theme for zsh highlighting
├── scripts/doctor.sh           Drift detection & repair tool (run: dots-doctor)
├── Brewfile                    All Homebrew dependencies
└── install.sh                  Bootstrap script
```

## Repair & Drift Check

Configs are symlinked from this repo into your home directory. Apps that rewrite
their own config atomically (Claude Code's `settings.json`) are **seeded**
(copied) instead, since they'd break a symlink. Two commands keep things healthy:

```bash
dots-doctor          # check symlinks, PATH, portability — exits non-zero on drift
dots-doctor --fix    # back up + re-link drifted configs, seed missing ones
```

Aliases `dots`, `dots-doctor`, and `dots-update` are defined in `.zshrc`.

### `~/.zshrc.local` — machine-local overrides

Installer-managed blocks (bun, shell completions, the `claude-auto-retry`
wrapper, etc.) live in `~/.zshrc.local`, **not** the tracked `.zshrc`. This
keeps installers that append to your rc from corrupting the committed file.
The first install seeds it from `zsh/.zshrc.local.example`; edit it freely.

## Agent navigation and validation

`graphify-navigation` is a shared Claude/Codex skill for using existing graphs
on architecture and dependency questions. It checks the indexed corpus first,
queries narrowly, and verifies current sources. Missing or unidentified graphs
fall back to ordinary search; partial graphs only help locate current sources.
The separately installed upstream `graphify` skill
continues to own explicit builds and semantic extraction; its installation is
not replaced by the dotfiles installer. The freshness helper uses the installed
Graphify CLI's Python interpreter without running a package manager.

RTK is installed through the Brewfile. Agents follow [RTK guidance](agents/RTK.md)
for verbose local validation, without a command-rewrite hook. Configuration
keeps telemetry off, retains the last 20 raw outputs per output directory (up to
16 MiB each), and tracks local output savings for 30 days. Start a new agent
session after setup so it discovers the navigation skill and instructions.

`install.sh` links the shared skill and RTK configuration. To disable this
integration, remove the `graphify-navigation` links in `~/.claude/skills` and
`~/.codex/skills`, the Claude Graphify/RTK rules, and the corresponding navigation
and RTK pointers from your global agent instructions. RTK itself can be removed
with `brew uninstall rtk`; no hook or shell alias needs undoing.

Verify graph coverage handling locally with:

```sh
uv tool run --offline --no-cache --from graphifyy python -m unittest discover \
  -s agents/skills/graphify-navigation/scripts -p 'test_*.py'
```

## Updating dotfiles

```bash
dots-update          # git pull ~/dotfiles (alias defined in .zshrc)
dots-doctor --fix    # re-link any changed configs, seed missing ones
```

`./install.sh` is still the full re-run path (idempotent, safe any time), but
after a routine `git pull` you usually only need `dots-doctor --fix`.

## Font

Uses [JetBrains Mono Nerd Font](https://www.nerdfonts.com/font-downloads) — installed automatically via the Brewfile. Required for eza icons and Starship symbols.

## Tmux Cheat Sheet

Press `Ctrl+a ?` inside tmux to see the full cheat sheet, or see [tmux/cheatsheet.sh](tmux/cheatsheet.sh).

## Credits

- [Catppuccin](https://github.com/catppuccin/catppuccin) — color scheme across all tools
- Built with [Claude Code](https://claude.ai/claude-code)
