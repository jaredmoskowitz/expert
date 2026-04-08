#!/usr/bin/env bash

# Expert Mode — SessionStart hook
# Reads mode from data/expert-mode.txt
# If active, injects translation engine + profiles into additionalContext

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE_FILE="$PLUGIN_ROOT/data/expert-mode.txt"
PROFILES_DIR="$PLUGIN_ROOT/profiles"
CONTEXT_DIR="$PLUGIN_ROOT/context"

# Read current mode, default to "off" if file missing
if [ -f "$MODE_FILE" ]; then
  MODE="$(cat "$MODE_FILE" | tr -d '[:space:]')"
else
  MODE="off"
fi

# Exit silently if off
if [ "$MODE" = "off" ]; then
  cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ""
  }
}
EOF
  exit 0
fi

# --- Build the translation engine prompt ---

read -r -d '' ENGINE_PROMPT << 'ENGINEEOF'
# Expert Translation Mode: ACTIVE

You have an active expert translation layer. Before acting on each user message, follow this process:

## Translation Process

1. **Assess the message:** Is this a vague/novice statement that benefits from expert translation, or a concrete technical instruction that should pass through unchanged?
   - Pass-through examples: "read file X", "run tests", "commit this", "git status", any message that's already precise and actionable
   - Translate examples: vague intent, domain-naive phrasing, ambiguous requests

2. **If translation needed:**
   a. Select the most relevant expert profile(s) from the loaded profiles below based on message content
   b. If multiple profiles are relevant, blend their perspectives
   c. Reformulate the user's message through the expert lens(es)
   d. Show the translation as a brief note at the start of your response:
      - Single profile: `> **Expert translation [profile-name]:** reformulated message`
      - Multiple profiles: `> **Expert translation [profile1 + profile2]:** reformulated message`
   e. Then act on the translated version

3. **If ambiguous:** Ask ONE clarifying question using expert-level vocabulary and specific options grounded in the user's project. Not "what do you mean?" but domain-specific choices.

4. **If pass-through:** Act normally with no translation note.

## Important Rules
- Preserve the user's core intent — add precision, don't change direction
- Keep translations concise (2-4 sentences max)
- The translation note is informational, not an approval gate — show it and proceed
- When a project context file is loaded, reference specific files/configs in translations
ENGINEEOF

# --- Determine which profiles to load ---

PROFILES=""

if [ "$MODE" = "auto" ]; then
  # Auto mode: load ALL profiles so Claude can select per-message
  for profile in "$PROFILES_DIR"/*.md; do
    [ -f "$profile" ] || continue
    PROFILE_NAME=$(basename "$profile" .md)
    PROFILE_CONTENT=$(cat "$profile")
    PROFILES="${PROFILES}

---
## Expert Profile: ${PROFILE_NAME}
${PROFILE_CONTENT}"
  done
else
  # Forced single profile mode
  PROFILE_FILE="$PROFILES_DIR/${MODE}.md"
  if [ -f "$PROFILE_FILE" ]; then
    PROFILE_CONTENT=$(cat "$PROFILE_FILE")
    PROFILES="
---
## Expert Profile: ${MODE} (FORCED — always use this profile)
${PROFILE_CONTENT}"
  else
    PROFILES="
---
WARNING: Profile '${MODE}' not found in ${PROFILES_DIR}/. Available profiles:"
    for profile in "$PROFILES_DIR"/*.md; do
      [ -f "$profile" ] || continue
      PROFILES="${PROFILES}
- $(basename "$profile" .md)"
    done
  fi
fi

# --- Load project context if available ---

PROJECT_CONTEXT=""
# Try to detect current project from PWD or common patterns
CURRENT_DIR_NAME=$(basename "$(pwd)")
CONTEXT_FILE="$CONTEXT_DIR/${CURRENT_DIR_NAME}.md"

if [ -f "$CONTEXT_FILE" ]; then
  PROJECT_CONTEXT="

---
## Project Context: ${CURRENT_DIR_NAME}
$(cat "$CONTEXT_FILE")"
fi

# --- Combine everything ---

FULL_CONTEXT="${ENGINE_PROMPT}

# Loaded Expert Profiles
${PROFILES}
${PROJECT_CONTEXT}"

# Escape for JSON
ESCAPED_CONTEXT=$(printf '%s' "$FULL_CONTEXT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read())[1:-1])')

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${ESCAPED_CONTEXT}"
  }
}
EOF

exit 0
