#!/usr/bin/env bash
# Configures Mac mini for always-on headless operation.
set -euo pipefail

echo "Configuring power management (will prompt for sudo)..."

sudo pmset -a sleep 0           # never sleep the system
sudo pmset -a displaysleep 0    # never sleep the display
sudo pmset -a disksleep 0       # never sleep the disk
sudo pmset -a powernap 0        # disable Power Nap
sudo pmset -a womp 1            # Wake on LAN
sudo pmset -a tcpkeepalive 1    # keep TCP connections alive
sudo pmset -a autorestart 1     # auto-restart after power failure

echo ""
echo "Current pmset config:"
pmset -g custom
