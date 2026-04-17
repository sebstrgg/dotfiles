#!/usr/bin/env bash
set -euo pipefail
# Creates (or attaches to) the "main" tmux session with 5 named windows.
# Called from .zshrc on Ghostty launch or SSH connection.
# Idempotent: safe to call multiple times.

SESSION="main"

# If session exists, attach and exit
if tmux has-session -t "$SESSION" 2>/dev/null; then
    exec tmux attach -t "$SESSION"
fi

# Create session with first window named "shell"
tmux new-session -d -s "$SESSION" -n "shell"

# Create CLI windows (don't launch anything — user starts CLIs manually)
tmux new-window -t "$SESSION" -n "claude"
tmux new-window -t "$SESSION" -n "codex"
tmux new-window -t "$SESSION" -n "gemini"
tmux new-window -t "$SESSION" -n "kimi"

# Focus on shell window (name-based — immune to base-index config)
tmux select-window -t "$SESSION:shell"

# Attach
exec tmux attach -t "$SESSION"
