#!/usr/bin/env bash
# Snapshots Mac app preferences for migration to a new Mac.
# Writes to ~/Documents/setup-macos/ (iCloud Drive transfer path).
# Safe to run multiple times — overwrites previous snapshot.

set -euo pipefail

SNAPSHOT_DIR="$HOME/Documents/setup-macos"
mkdir -p "$SNAPSHOT_DIR/plists" "$SNAPSHOT_DIR/alfred" "$SNAPSHOT_DIR/linearmouse"

echo "→ Exporting app preferences to $SNAPSHOT_DIR"

# Bundle IDs to export — verified at runtime via `defaults domains`
# (missing domains = app not installed, skip gracefully)
DOMAINS=(
  "com.castdrian.ishare"
  "com.ejbills.DockDoor"
  "com.dwarvesv.MinimalBar"            # Hidden Bar — verify on first run
  "com.robotsandpencils.Dockey"        # Dockey — verify on first run
  "com.max-codes.Latest"               # Latest — verify on first run
  "com.xykong.FluxMarkdown"            # FluxMarkdown — verify on first run
)

for domain in "${DOMAINS[@]}"; do
  if defaults domains 2>/dev/null | tr ',' '\n' | grep -q "^\s*${domain}\s*$"; then
    defaults export "$domain" "$SNAPSHOT_DIR/plists/${domain}.plist"
    echo "  [OK]   $domain"
  else
    echo "  [SKIP] $domain (not installed)"
  fi
done

# LinearMouse — JSON config, not a plist
LM_SRC="$HOME/Library/Application Support/LinearMouse/linearmouse.json"
if [[ -f "$LM_SRC" ]]; then
  cp "$LM_SRC" "$SNAPSHOT_DIR/linearmouse/linearmouse.json"
  echo "  [OK]   LinearMouse JSON"
else
  echo "  [SKIP] LinearMouse JSON (not found)"
fi

# Alfred — use sync folder if set, else default Application Support path
ALFRED_SYNC=$(defaults read com.runningwithcrayons.Alfred-Preferences syncfolder 2>/dev/null || echo "")
if [[ -z "$ALFRED_SYNC" ]]; then
  ALFRED_SYNC="$HOME/Library/Application Support/Alfred"
fi
if [[ -d "$ALFRED_SYNC" ]]; then
  rsync -a --delete \
    --exclude='Databases' \
    --exclude='Caches' \
    --exclude='Alfred.alfredpreferences/history.plist' \
    "$ALFRED_SYNC/" "$SNAPSHOT_DIR/alfred/"
  echo "  [OK]   Alfred config from $ALFRED_SYNC"
else
  echo "  [SKIP] Alfred config (sync folder not found)"
fi

echo ""
echo "Snapshot complete."
echo "Next: review $SNAPSHOT_DIR and copy the clean portions into dotfiles/mac-apps/."
