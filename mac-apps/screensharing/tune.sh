#!/usr/bin/env bash
# Tunes the legacy VNC Screen Sharing path for maximum quality.
# Tahoe's new "High Performance" mode (Screen Sharing.app) is the preferred path —
# this is the fallback for restricted networks where High Performance isn't available.
set -euo pipefail

defaults write com.apple.ScreenSharing controlObserveQuality -int 5    # max quality
defaults write com.apple.ScreenSharing SkipChecksum -bool true          # skip data integrity check
defaults write com.apple.ScreenSharing dontWarnOnDisconnect -bool true

echo "Screen Sharing (VNC fallback) tuned."
echo ""
echo "For best quality, use the new Screen Sharing app with High Performance mode:"
echo "  /System/Applications/Utilities/Screen Sharing.app"
echo "  (Not: Finder → Connect to Server → vnc://)"
