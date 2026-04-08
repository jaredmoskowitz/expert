---
description: "Toggle expert translation mode — /expert on, /expert <profile>, /expert off, or /expert for status"
argument-hint: "[on|off|<profile-name>]"
allowed-tools: [Read, Write, Bash, Edit, Glob]
---

# Expert Translation Mode Toggle

The user invoked: `/expert $ARGUMENTS`

## Instructions

**Mode file:** Use the Bash tool to resolve the path:
```bash
PLUGIN_ROOT="$(cd "$(dirname "$(find ~/.claude/plugins -path '*/expert/commands/expert.md' -print -quit)")/.." && pwd)"
echo "$PLUGIN_ROOT/data/expert-mode.txt"
```

Also resolve the profiles directory:
```bash
echo "$PLUGIN_ROOT/profiles"
```

Read the current mode from the mode file first. Then list available profiles by reading `*.md` filenames in the profiles directory.

### If argument is "on":

1. Write `auto` to the mode file
2. Read back to confirm
3. List available profiles by scanning the profiles directory
4. Respond:
   > Expert mode **activated** (auto). I'll auto-select the right expert profile(s) for each message.
   >
   > Available profiles: [list profile names]
   >
   > Mode change takes effect on your next session.

### If argument is "off":

1. Write `off` to the mode file
2. Read back to confirm
3. Respond:
   > Expert mode **disabled**. I'll respond normally without expert translation.
   >
   > Mode change takes effect on your next session.

### If argument matches a profile name:

1. Check if a file named `<argument>.md` exists in the profiles directory
2. If yes: write the argument to the mode file, read back to confirm
3. Respond:
   > Expert mode **activated** with forced profile: **<profile-name>**. All messages will be translated through this expert lens.
   >
   > Mode change takes effect on your next session.
4. If no matching profile: list available profiles and suggest the closest match or `on` for auto mode.

### If no argument (or unrecognized argument):

Read the current mode and list available profiles:

```
Expert Mode Status: [current mode]

  auto  — active, auto-selects profile(s) per message
  off   — active, no translation
  <name> — active, forced to specific profile

Available profiles:
  [list each .md file in profiles/ without extension]

Usage:
  /expert on         — activate in auto mode (recommended)
  /expert <profile>  — force a specific profile
  /expert off        — disable

Current mode takes effect at session start. Change persists across sessions.
```
