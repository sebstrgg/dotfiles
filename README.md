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

### Development disk trimming (macOS)

`bin/dev-disk-trim` measures Data-volume use as used / (used + available).
Above 58%, it trims reproducible development output and caches in order, stopping
at 55%. `--dry-run` reports actions; `--force` bypasses the starting threshold.
Busy builds keep their output; failed process/file inspections keep the data.
The hourly launch agent also runs at load. JSON actions and before/after usage
are logged to `~/Library/Logs/dev-disk-trim.log`, capped below 1 MiB.
Docker requests are bounded with GNU `timeout` (Homebrew `coreutils`); Docker
pruning is skipped if that tool or a responsive daemon is unavailable.

The Kimsufi `tools/dev-clean.sh`, its worktree variants, and identical copies are
skipped because it also deletes protected scratch data and worktrees; its Rust
target is handled directly. Agent databases,
Docker volumes, CoreSimulator, and project sources are excluded. This can exhaust
the safe candidates before reaching 55%; it does not guarantee a usage ceiling.

Install or update explicitly:

```bash
install -m 755 bin/dev-disk-trim ~/.local/bin/dev-disk-trim
cp launchd/com.sebastian.dev-disk-trim.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.sebastian.dev-disk-trim.plist
dev-disk-trim --dry-run --force
```

Offline checks: `bash tests/dev-disk-trim.test.sh`,
`shellcheck bin/dev-disk-trim tests/dev-disk-trim.test.sh`, and
`shfmt -d bin/dev-disk-trim tests/dev-disk-trim.test.sh`.

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

Installer-managed blocks (bun, shell completions, etc.) live in
`~/.zshrc.local`, **not** the tracked `.zshrc`. This keeps installers that
append to your rc from corrupting the committed file.
The first install seeds it from `zsh/.zshrc.local.example`; edit it freely.

## Global agent workflows

These integrations are user-wide for Claude Code and Codex on the configured
machine. Start a new agent session after installation.

- **Policy.** `agents/global-instructions.md` is private (gitignored) and is
  linked as `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. A public clone has
  no copy; the installer warns and skips it.
- **Skills**, linked into both runtimes:
  [`engineering-workflow`](agents/skills/engineering-workflow/SKILL.md) is the
  single path from request to verified result and routes to the other
  playbooks (Matt Pocock's library, installed separately under
  `~/.agents/skills`). [`verify`](agents/skills/verify/SKILL.md) is the
  independent done-check, [`delegate`](agents/skills/delegate/SKILL.md) covers
  models and workers, [`continue`](agents/skills/continue/SKILL.md) starts a
  fresh session from an effort file, and
  [`weekly-review`](agents/skills/weekly-review/SKILL.md) is run on a weekly
  schedule.
- **Effort files.** Work state lives in `.scratch/<effort>/effort.md` in the
  project (gitignored). [`bin/effort-gate`](bin/effort-gate) `new <effort>`
  creates one from
  [the template](agents/skills/engineering-workflow/templates/effort.md), owned
  by the calling agent session (front matter `session:`); `claim <file>` hands
  it to another session. As the Stop hook it keeps the owner from ending its
  turn while the file has unfinished "done when" items; while a recorded task
  is `running`, Claude (which wakes the session when the task ends) may stop
  and Codex is asked for a blocking wait. As the post-compaction hook it points
  the owner back at the file, in any worktree of the repository. Other
  sessions in the same checkout are not gated, and a run `agent-run` started
  for an orchestrator is neither gated nor allowed to create or claim an
  effort file. `.scratch/` is kept out of git through the repository's
  `info/exclude`. Hooks: `claude/settings.json`, `codex/hooks.json`
  (Codex asks once to trust new hooks via `/hooks`). A "done when" item marked
  `pass` on evidence labelled a substitute stays open, also in an effort set
  to `done`. At close it holds the owner once if items passed without a
  finished `agent-run` verify by the other runtime under the effort's `runs/`
  that started after the checkout's newest commit, and once if "Not approved"
  lists actions (list items or `;`-separated) the last message does not ask.
  Tests:
  `python3 tests/effort-gate.test.py`.
- **Cross-runtime runs.** [`bin/agent-run`](bin/agent-run) starts a detached
  `codex exec` or `claude -p` run for a role (`work`, `continue`, `verify`,
  `review`) with model, effort and access pinned, the prompt and results in a
  run folder, `wait` blocks until it ends, and `resume` continues a finished
  or stopped run's session in a new run folder with the same pins. Codex
  lanes start signed out of Claude. Runs other than `continue` carry
  `AGENT_RUN_ROLE` and cannot start or resume further runs. Tests:
  `python3 tests/agent-run.test.py`.
- **Tripwires.** [`bin/agent-tripwire`](bin/agent-tripwire), a PreToolUse hook
  in both runtimes, refuses `git push` with `--force`, `-f` or a `+refspec`
  wherever the flag sits; `--force-with-lease` stays allowed. It also refuses
  a `ps` or `pgrep` that could print process arguments, which can carry
  secrets: only a names-only listing such as `ps -Ao pid,rss,comm` passes.
  Alongside it, `claude/settings.json` denies, and
  [`codex/rules/tripwires.rules`](codex/rules/tripwires.rules) forbids, the
  common force-push forms, repository deletion and settings changes, Docker
  volume removal and wiping `/` or `~`. They catch the usual spellings, not a
  push hidden in a script or `sh -c`: a tripwire, not a boundary. Codex
  ignores symlinked rule files, so the installer copies this one. Tests:
  `python3 tests/agent-tripwire.test.py`.
- **Clock.** A UserPromptSubmit hook in both runtimes adds the Stockholm local
  time to each prompt, so ETAs start from the real clock.
- `bin/agent-messages --days N` lists Sebastian's own messages from local
  Claude and Codex sessions, for the weekly review.

`dots-doctor` checks the links, the copied tripwire file, the seeded settings
and the agent setup's keys in the live Claude and Codex configs;
`dots-doctor --fix` repairs drift.

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
