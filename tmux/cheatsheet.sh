#!/usr/bin/env bash
cat << 'EOF'

  Ghostty + tmux Cheat Sheet
  ══════════════════════════════════════════════

  ── Panes ──────────────────────────────────
  Shift+arrows       switch panes (no prefix!)
  Ctrl+a  v          split side-by-side
  Ctrl+a  -          split top/bottom
  Ctrl+a  h j k l    navigate panes (alt)
  Ctrl+a  H J K L    resize panes
  Ctrl+a  z          zoom / unzoom pane
  Ctrl+a  x          kill pane

  ── Windows ────────────────────────────────
  Ctrl+a  c          new window
  Ctrl+a  n / p      next / prev window
  Ctrl+a  1-9        jump to window
  Ctrl+a  ,          rename window
  Ctrl+a  X          kill window

  ── Session ────────────────────────────────
  Ctrl+a  d          detach session
  Ctrl+a  Ctrl+s     save layout (resurrect)
  Ctrl+a  Ctrl+r     restore layout (resurrect)
  Ctrl+a  m          toggle mouse (for drag-drop)
  Ctrl+a  r          reload config

  ── Tips ───────────────────────────────────
  Shift+drag         drag files even with mouse on
  Cmd+Shift+click    open URLs in browser

  ── This Help ──────────────────────────────
  Ctrl+a  ?          show this cheat sheet
  Escape / q         close this popup

EOF
read -n 1 -s
