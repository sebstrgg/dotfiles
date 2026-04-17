#!/usr/bin/env bash
# Disables macOS symbolic hotkeys that conflict with Alfred and iShare.
# Tahoe-tested; IDs stable across macOS 24, 25, 26.

set -euo pipefail

# 64 = Spotlight (⌘Space)
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 \
  '{ enabled = 0; value = { parameters = (32, 49, 1048576); type = standard; }; }'

# Screenshot shortcuts: 28 = ⌘⇧3, 29 = ⌃⌘⇧3, 30 = ⌘⇧4, 31 = ⌃⌘⇧4, 184 = ⌘⇧5
for key in 28 29 30 31 184; do
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$key" \
    '{ enabled = 0; }'
done

# Force reload so changes take effect this login (not after logout)
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

# Verification: report any key that didn't take
echo ""
echo "Verification:"
for key in 28 29 30 31 64 184; do
  enabled=$(defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys 2>/dev/null \
    | awk "/^    $key =/,/^    };/" \
    | grep -o 'enabled = [01]' \
    | head -1 \
    | awk '{print $3}' || echo "?")
  if [[ "$enabled" == "0;" || "$enabled" == "0" ]]; then
    echo "  [OK]   key $key disabled"
  else
    echo "  [WARN] key $key not disabled — fall back to System Settings → Keyboard → Keyboard Shortcuts"
  fi
done
