#!/bin/bash
# Claude Code Status Line — 2-line dev dashboard
# Reads JSON session data from stdin, prints formatted 2-line status to stdout.
#
# Line 1: Model │ Project/Agent │ ctx bar │ usage bar ↻HH:MM
# Line 2: files changed · branch · tokens · latest commit
#
# INSTALL
#   Copy to ~/.claude/statusline.sh and chmod +x
#
# GLOBAL CONFIG (required once, in ~/.claude/settings.json):
#   "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "padding": 2 }
#
# PER-PROJECT AGENT OVERRIDE (optional):
#   Create .claude/statusline.json in any git repo root to customize the
#   agent name shown in the status line for that project.
#
#   Example — .claude/statusline.json:
#     { "agent": "Neo" }
#
#   When present, the "agent" value replaces the default "interactive" label.
#   When absent, the session's agent name is used as-is (typically "interactive").
#   Subagents always show their own name regardless of this config.
#
# EFFORT LEVEL DISPLAY:
#   The thinking effort level (low/medium/high/max) is not yet in the statusline
#   JSON from Anthropic (tracked: github.com/anthropics/claude-code/issues/31415).
#   Workaround: reads effortLevel from settings.json with this priority chain:
#     1. CLAUDE_CODE_EFFORT_LEVEL env var (if set at launch)
#     2. Project .claude/settings.json (effortLevel field)
#     3. User ~/.claude/settings.json (effortLevel field)
#     4. Default: "medium"
#   When Anthropic adds the field to stdin JSON, switch to reading it directly.

set -f  # disable globbing

# Timeout wrapper — uses timeout if available, otherwise runs without timeout
run_with_timeout() {
    local secs="$1"; shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$secs" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$secs" "$@"  # Homebrew coreutils on macOS
    else
        "$@"  # No timeout available, run directly
    fi
}

input=$(cat)

# ---------- Parse JSON fields with graceful fallbacks ----------

MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"' 2>/dev/null)
AGENT=$(echo "$input" | jq -r '.agent.name // "interactive"' 2>/dev/null)
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' 2>/dev/null | cut -d. -f1)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0' 2>/dev/null)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0' 2>/dev/null | cut -d. -f1)
FIVE_HOUR_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0' 2>/dev/null | cut -d. -f1)
SEVEN_DAY_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // 0' 2>/dev/null | cut -d. -f1)
FIVE_HOUR_RESETS_AT=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)
SESSION_ID=$(echo "$input" | jq -r '.session_id // ""' 2>/dev/null)

# Background agents count — check multiple paths
BG_COUNT=$(echo "$input" | jq -r '
    [(.background_agents // [])[], (.agents // [])[]]
    | length
' 2>/dev/null)
[ -z "$BG_COUNT" ] && BG_COUNT=0

# ---------- ANSI color codes ----------

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ---------- Helper: color by threshold ----------
color_for() {
    local val="${1:-0}"
    if [ "$val" -ge 80 ] 2>/dev/null; then
        echo "$RED"
    elif [ "$val" -ge 50 ] 2>/dev/null; then
        echo "$YELLOW"
    else
        echo "$GREEN"
    fi
}

# ---------- Helper: build 10-block bar ----------
bar10() {
    local pct="${1:-0}" bar=""
    local filled=$((pct / 10))
    [ "$filled" -gt 10 ] && filled=10
    [ "$filled" -lt 0 ] && filled=0
    local empty=$((10 - filled))
    for ((i=0; i<filled; i++)); do bar="${bar}▰"; done
    for ((i=0; i<empty; i++)); do bar="${bar}▱"; done
    echo "$bar"
}

# ---------- Format model name with version and context window ----------
short_model() {
    local raw="$1"
    # Extract tier name
    local tier
    case "$raw" in
        *Opus*)   tier="Opus" ;;
        *Sonnet*) tier="Sonnet" ;;
        *Haiku*)  tier="Haiku" ;;
        *)        echo "$raw"; return ;;
    esac
    # Extract version number (e.g. "4.6" from "claude-opus-4-6-..." or "4.5" from display names)
    local ver
    ver=$(echo "$raw" | grep -oE '[0-9]+\.[0-9]+' | head -1)
    # Extract context window from the JSON input (in tokens → convert to K/M label)
    local ctx_tokens ctx_label
    ctx_tokens=$(echo "$input" | jq -r '.context_window.context_window_size // 0' 2>/dev/null | cut -d. -f1)
    if [ "${ctx_tokens:-0}" -ge 1000000 ]; then
        ctx_label="$(( ctx_tokens / 1000000 ))M"
    elif [ "${ctx_tokens:-0}" -ge 1000 ]; then
        ctx_label="$(( ctx_tokens / 1000 ))K"
    else
        ctx_label=""
    fi
    # Build label: "Opus 4.6 (200K)" or "Opus 4.6" or just "Opus"
    local label="$tier"
    [ -n "$ver" ] && label="$label $ver"
    [ -n "$ctx_label" ] && label="$label (${ctx_label})"
    echo "$label"
}

MODEL_SHORT=$(short_model "$MODEL")

# ---------- Git root (used by project name, agent override, effort) ----------
GIT_ROOT=""
if run_with_timeout 2 git rev-parse --show-toplevel > /dev/null 2>&1; then
    GIT_ROOT=$(run_with_timeout 2 git rev-parse --show-toplevel 2>/dev/null)
fi

# ---------- Effort level (workaround until Anthropic adds to statusline JSON) ----------
# Priority: env var > project .claude/settings.json > user ~/.claude/settings.json > "medium"
# Tracks: github.com/anthropics/claude-code/issues/31415
EFFORT="${CLAUDE_CODE_EFFORT_LEVEL:-}"
if [ -z "$EFFORT" ] && [ -n "$GIT_ROOT" ]; then
    EFFORT=$(jq -r '.effortLevel // empty' "${GIT_ROOT}/.claude/settings.json" 2>/dev/null)
fi
if [ -z "$EFFORT" ]; then
    EFFORT=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)
fi
EFFORT="${EFFORT:-medium}"

# ---------- Project name from git root ----------
PROJECT=$(basename "${GIT_ROOT:-$PWD}" | sed 's/^__//;s/__$//')

# ---------- Per-project agent override ----------
# If the session agent is "interactive" (main chat), check for a project-level
# config at <repo-root>/.claude/statusline.json with an "agent" field.
if [ "$AGENT" = "interactive" ] && [ -n "$GIT_ROOT" ]; then
    PROJECT_CONFIG="${GIT_ROOT}/.claude/statusline.json"
    if [ -f "$PROJECT_CONFIG" ]; then
        OVERRIDE=$(jq -r '.agent // empty' "$PROJECT_CONFIG" 2>/dev/null)
        [ -n "$OVERRIDE" ] && AGENT="$OVERRIDE"
    fi
fi

# ---------- Cross-session shared state for usage ----------
STATE_FILE="/tmp/claude-usage-state.json"
USAGE_PCT="$FIVE_HOUR_PCT"
RESET_TIME=""

# Priority 1: Use resets_at from stdin JSON (authoritative from Claude Code)
if [ -n "$FIVE_HOUR_RESETS_AT" ]; then
    RESET_TIME=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$FIVE_HOUR_RESETS_AT" | sed 's/Z$//; s/+.*//')" +%H:%M 2>/dev/null)
    # If date -j fails (non-macOS), try GNU date
    if [ -z "$RESET_TIME" ]; then
        RESET_TIME=$(date -d "$FIVE_HOUR_RESETS_AT" +%H:%M 2>/dev/null)
    fi
    # Last resort: just extract HH:MM from the ISO string directly
    if [ -z "$RESET_TIME" ]; then
        RESET_TIME=$(echo "$FIVE_HOUR_RESETS_AT" | grep -oE '[0-9]{2}:[0-9]{2}' | head -1)
    fi
fi

# Priority 2: Try API helper
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_SCRIPT="$SCRIPT_DIR/claude-usage-api.py"

if [ -f "$API_SCRIPT" ]; then
    API_OUTPUT=$(run_with_timeout 3 python3 "$API_SCRIPT" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$API_OUTPUT" ]; then
        API_5H=$(echo "$API_OUTPUT" | jq -r '.five_hour_pct // empty' 2>/dev/null | cut -d. -f1)
        API_RESET=$(echo "$API_OUTPUT" | jq -r '.reset_display // empty' 2>/dev/null)
        [ -n "$API_5H" ] && [ "$USAGE_PCT" -eq 0 ] 2>/dev/null && USAGE_PCT="$API_5H"
        [ -n "$API_RESET" ] && [ -z "$RESET_TIME" ] && RESET_TIME="$API_RESET"
    fi
fi

# Priority 3: Shared state file (only if <5 min old)
if [ -f "$STATE_FILE" ]; then
    STATE_AGE=$(( $(date +%s) - $(stat -f %m "$STATE_FILE" 2>/dev/null || stat -c %Y "$STATE_FILE" 2>/dev/null || echo 0) ))
    if [ "$STATE_AGE" -lt 300 ]; then
        CACHED_PCT=$(jq -r '.five_hour_pct // empty' "$STATE_FILE" 2>/dev/null)
        CACHED_RESET=$(jq -r '.reset_time // empty' "$STATE_FILE" 2>/dev/null)
        [ -n "$CACHED_PCT" ] && [ "$USAGE_PCT" -eq 0 ] 2>/dev/null && USAGE_PCT="$CACHED_PCT"
        [ -n "$CACHED_RESET" ] && [ -z "$RESET_TIME" ] && RESET_TIME="$CACHED_RESET"
    fi
fi

# Priority 4: Estimate reset time if still missing
if [ -z "$RESET_TIME" ] && [ "$USAGE_PCT" -gt 0 ] 2>/dev/null; then
    RESET_TS=$(( $(date +%s) + 5 * 3600 ))
    RESET_TIME=$(date -r "$RESET_TS" +%H:%M 2>/dev/null || date -d "@$RESET_TS" +%H:%M 2>/dev/null || echo "")
fi

# Write shared state (atomic via mv, deduplicate)
if [ -n "$SESSION_ID" ]; then
    TMP_STATE=$(mktemp /tmp/claude-usage-state.XXXXXX 2>/dev/null)
    if [ -n "$TMP_STATE" ]; then
        cat > "$TMP_STATE" << EOF2
{"five_hour_pct":${USAGE_PCT:-0},"seven_day_pct":${SEVEN_DAY_PCT:-0},"reset_time":"${RESET_TIME}","session_id":"${SESSION_ID}","ts":$(date +%s)}
EOF2
        mv "$TMP_STATE" "$STATE_FILE" 2>/dev/null
    fi
fi

# Clean up old rate marker file
rm -f /tmp/claude-rate-start

# ---------- Context bar ----------
CTX_COLOR=$(color_for "$CTX_PCT")
CTX_BAR=$(bar10 "$CTX_PCT")

# ---------- Usage bar ----------
USAGE_COLOR=$(color_for "$USAGE_PCT")
USAGE_BAR=$(bar10 "$USAGE_PCT")
# RESET_TIME is used in LINE1's reset section

# ---------- Duration formatting ----------
format_duration() {
    local ms="${1:-0}" total_sec
    total_sec=$((ms / 1000))
    local hours=$((total_sec / 3600))
    local mins=$(( (total_sec % 3600) / 60 ))
    if [ "$hours" -gt 0 ]; then
        echo "${hours}h ${mins}m"
    elif [ "$mins" -gt 0 ]; then
        echo "${mins}m"
    else
        echo "<1m"
    fi
}

DURATION=$(format_duration "$DURATION_MS")

# ---------- Token estimation ----------
estimate_tokens() {
    local cost="$1" model="$2"
    # Approximate cost per 1M tokens (blended input/output)
    local rate
    case "$model" in
        *Opus*)   rate=45 ;;
        *Sonnet*) rate=9 ;;
        *Haiku*)  rate=2.4 ;;
        *)        rate=15 ;;
    esac
    # tokens = (cost / rate) * 1,000,000 → display as K
    local tokens_k
    tokens_k=$(echo "$cost $rate" | awk '{if ($2 > 0) printf "%.0f", ($1 / $2) * 1000; else print "0"}')
    echo "${tokens_k}K"
}

TOKENS=$(estimate_tokens "$COST" "$MODEL")

# ---------- Last commit (timeout-wrapped) ----------
COMMIT_INFO=""
if run_with_timeout 2 git rev-parse --git-dir > /dev/null 2>&1; then
    COMMIT_HASH=$(run_with_timeout 2 git log -1 --pretty=format:'%h' 2>/dev/null)
    COMMIT_AGO=$(run_with_timeout 2 git log -1 --pretty=format:'%cr' 2>/dev/null | sed 's/ seconds\{0,1\}/s/; s/ minutes\{0,1\}/m/; s/ hours\{0,1\}/h/; s/ days\{0,1\}/d/; s/ weeks\{0,1\}/w/; s/ months\{0,1\}/mo/; s/ years\{0,1\}/y/')
    [ -n "$COMMIT_HASH" ] && COMMIT_INFO="commit ${COMMIT_HASH} (${COMMIT_AGO})"
fi

# ---------- Current PR (timeout-wrapped) ----------
PR_INFO=""
if [ -n "$GIT_ROOT" ] && command -v gh >/dev/null 2>&1; then
    PR_NUM=$(run_with_timeout 3 gh pr view --json number --jq '.number' 2>/dev/null)
    [ -n "$PR_NUM" ] && PR_INFO="PR #${PR_NUM}"
fi

# ---------- Snapshot logging ----------
SNAPSHOT_FILE="${CLAUDE_STATUSLINE_SNAPSHOT_DIR:-$SCRIPT_DIR/../data}/usage-snapshots.jsonl"
if [ -n "$SESSION_ID" ] && [ -d "$(dirname "$SNAPSHOT_FILE")" ]; then
    NOW_TS=$(date +%s)
    # Deduplicate: skip if same session_id within last 30 seconds
    SHOULD_LOG=1
    if [ -f "$SNAPSHOT_FILE" ]; then
        LAST_ENTRY=$(tail -1 "$SNAPSHOT_FILE" 2>/dev/null)
        LAST_SID=$(echo "$LAST_ENTRY" | jq -r '.session_id // ""' 2>/dev/null)
        LAST_TS=$(echo "$LAST_ENTRY" | jq -r '.ts // 0' 2>/dev/null)
        if [ "$LAST_SID" = "$SESSION_ID" ] && [ $((NOW_TS - LAST_TS)) -lt 30 ] 2>/dev/null; then
            SHOULD_LOG=0
        fi
    fi
    if [ "$SHOULD_LOG" -eq 1 ]; then
        # Detect if this is a subagent
        IS_SUBAGENT=false
        [[ -n "${CLAUDE_AGENT_TYPE:-}" ]] || [[ -n "${CLAUDE_SPAWNED:-}" ]] && IS_SUBAGENT=true
        echo "{\"ts\":${NOW_TS},\"session_id\":\"${SESSION_ID}\",\"model\":\"${MODEL_SHORT}\",\"context_pct\":${CTX_PCT:-0},\"five_hour_pct\":${USAGE_PCT:-0},\"seven_day_pct\":${SEVEN_DAY_PCT:-0},\"cost_usd\":${COST},\"duration_ms\":${DURATION_MS},\"agent\":\"${AGENT}\",\"is_subagent\":${IS_SUBAGENT},\"background_agents\":${BG_COUNT}}" >> "$SNAPSHOT_FILE"
    fi
fi

# ---------- LINE 1: Live metrics ----------
SEP="${DIM}│${RESET}"

# Tokens in ctx section (parenthesized)
CTX_TOKENS=""
[ -n "$TOKENS" ] && [ "$TOKENS" != "0K" ] && CTX_TOKENS=" (${TOKENS})"

# Reset section: labeled instead of icon
RESET_SECTION=""
[ -n "$RESET_TIME" ] && RESET_SECTION=" ${SEP} ${DIM}reset ${RESET_TIME}${RESET}"

LINE1="${BOLD}${MODEL_SHORT}${RESET} ${DIM}${EFFORT}${RESET} ${SEP} ${CYAN}${PROJECT}/${AGENT}${RESET} ${SEP} ${CTX_COLOR}ctx ${CTX_BAR} ${CTX_PCT}%${CTX_TOKENS}${RESET} ${SEP} ${USAGE_COLOR}usage ${USAGE_BAR} ${USAGE_PCT}%${RESET}${RESET_SECTION}"

# ---------- Git branch + changes ----------
GIT_CHANGES_INFO=""
GIT_BRANCH=""
if run_with_timeout 2 git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_BRANCH=$(run_with_timeout 2 git branch --show-current 2>/dev/null)
    [ -z "$GIT_BRANCH" ] && GIT_BRANCH="(detached)"
    GIT_CHANGES=$(run_with_timeout 2 git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$GIT_CHANGES" -eq 0 ] 2>/dev/null; then
        GIT_CHANGES_INFO="${GREEN}✓ clean${RESET}"
    elif [ "$GIT_CHANGES" -le 3 ] 2>/dev/null; then
        GIT_CHANGES_INFO="${YELLOW}${GIT_CHANGES} files changed${RESET}"
    else
        GIT_CHANGES_INFO="${RED}${GIT_CHANGES} files changed${RESET}"
    fi
fi

# ---------- LINE 2: Session context ----------
PARTS=()
[ -n "$GIT_CHANGES_INFO" ] && PARTS+=("${GIT_CHANGES_INFO}")
[ -n "$GIT_BRANCH" ] && PARTS+=("${CYAN}${GIT_BRANCH}${RESET}")
[ -n "$PR_INFO" ] && PARTS+=("${GREEN}${PR_INFO}${RESET}")
[ -n "$COMMIT_INFO" ] && PARTS+=("${COMMIT_INFO}")
[ "$BG_COUNT" -gt 0 ] 2>/dev/null && PARTS+=("▸▸ ${BG_COUNT} agents")

# Join with " · "
LINE2_CONTENT=""
for i in "${!PARTS[@]}"; do
    [ "$i" -gt 0 ] && LINE2_CONTENT="${LINE2_CONTENT} · "
    LINE2_CONTENT="${LINE2_CONTENT}${PARTS[$i]}"
done

LINE2="${DIM}${LINE2_CONTENT}${RESET}"

# ---------- Output ----------
echo -e "$LINE1"
echo -e "$LINE2"
