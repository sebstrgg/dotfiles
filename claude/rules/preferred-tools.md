---
alwaysApply: true
---

# Preferred CLI Tools

This machine has modern replacements for classic Unix tools installed. Prefer these when suggesting or running commands.

## Search and navigation

| Instead of | Use | Why |
|-----------|-----|-----|
| `grep` | `rg` (ripgrep) | ~10x faster, respects `.gitignore`, Unicode default. Claude Code's Grep tool already uses this under the hood. |
| `find` | `fd` | Simpler syntax, respects `.gitignore`, faster. |
| `cat` | `bat` | Syntax highlighting, line numbers. Stdout identical when piping. |
| `ls` | `eza` | Icons, colors, tree view via `eza --tree`. |
| `cd <dir>` | `z <partial>` | zoxide learns frequently-visited dirs. `z dot` jumps to `~/dotfiles` etc. |

## Structured data

- **JSON**: always pipe through `jq` for filtering and pretty-printing. Examples:
  - `curl -s <url> | jq '.items[] | {name, id}'`
  - `docker inspect <container> | jq '.[0].NetworkSettings.Ports'`
- **YAML**: use `yq` (the Go version by Mike Farah — NOT python-yq). Same syntax as `jq`.

## Python

- **Package management**: `uv` (not pip, not poetry, not pipx). Examples:
  - `uv pip install <pkg>` — install into current venv
  - `uv venv` — create venv
  - `uv run <script.py>` — run with auto-venv
- **Linting**: `ruff check .`
- **Type-checking**: whatever the project uses (`mypy`, `ty`, `pyright`); check `pyproject.toml`.

## Shell scripting

Before committing any shell script:

```bash
shellcheck <file>   # lints — warnings about quoting, error handling, portability
shfmt -d <file>     # shows formatting diffs
shfmt -w <file>     # applies formatting in place
```

Both are installed. Use them.

## Git

- Diffs are rendered through `delta` (configured in `~/.gitconfig`). No extra action needed.
- SSH is backed by the Bitwarden SSH agent on macOS (`SSH_AUTH_SOCK` points to Bitwarden socket) — keys live encrypted in the vault, never on disk.

## Shell history

- `atuin` replaces `Ctrl+R`. Fuzzy search, cross-machine sync via self-hosted server.
- Work machines: skip `atuin login` — local-only history, no sync.

## Docker

- Docker Engine runs under OrbStack (native Apple Virtualization, replaces Docker Desktop). Same `docker` / `docker-compose` CLI — just a faster VM underneath.

## When not to substitute

- Don't alias `grep` -> `rg` in scripts — scripts expect POSIX behavior. Use the right tool explicitly.
- When a user asks for a specific tool ("show me with grep"), honor that.
- When writing portable shell scripts that might run on machines without these tools, use POSIX-standard tools.
