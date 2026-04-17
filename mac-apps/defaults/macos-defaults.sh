#!/usr/bin/env bash
# macOS sensible defaults for Tahoe 26. Idempotent.
set -euo pipefail

# ── Finder ───────────────────────────────────────────
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Calculate folder sizes in list view (PlistBuddy — nested dict, no clean `defaults` path)
/usr/libexec/PlistBuddy -c \
  "Set :StandardViewSettings:ListViewSettings:calculateAllSizes true" \
  ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || \
  /usr/libexec/PlistBuddy -c \
  "Add :StandardViewSettings:ListViewSettings:calculateAllSizes bool true" \
  ~/Library/Preferences/com.apple.finder.plist

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true
# Unhide ~/Library
chflags nohidden ~/Library
# Hide desktop icons (connected drives, external HDs, etc.)
defaults write com.apple.finder CreateDesktop -bool false

# ── Dock ─────────────────────────────────────────────
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-time-modifier -float 0.3
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock minimize-to-application -bool true

# ── Screenshots (macOS capture UI, not iShare) ───────
mkdir -p "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture location "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# ── Keyboard / Input ─────────────────────────────────
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# ── UI ───────────────────────────────────────────────
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true

# Disable "natural" scroll direction
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# ── Security ─────────────────────────────────────────
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# ── Mail.app ─────────────────────────────────────────
defaults write com.apple.mail DisableSendAnimations -bool true
defaults write com.apple.mail DisableReplyAnimations -bool true
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false
defaults write com.apple.mail ConversationViewSortDescending -bool true
defaults write com.apple.mail DisableInlineAttachmentViewing -bool true
defaults write com.apple.mail SpellCheckingBehavior -string "InlineSpellCheckingEnabled"

# ── Screen saver (disabled — headless wastes CPU even in Screen Sharing) ──
defaults -currentHost write com.apple.screensaver idleTime -int 0

# ── Apply ────────────────────────────────────────────
killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
