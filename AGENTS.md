# AGENTS.md

Guidance for AI coding agents (Codex, Cursor, Claude Code, etc.) working in this repo.

## What this is

**Expert** is a Claude Code plugin that sits between vague user prompts and Claude's execution layer. On each message it can reformulate naive phrasing through domain personas (profiles) before acting. Markdown-only — no build step and no packaged dependencies beyond what the user's machine already has (bash + `python3` for JSON escaping in the SessionStart hook).

## Repo layout

```
.claude-plugin/
  plugin.json          # Claude Code plugin manifest
  marketplace.json     # Marketplace listing (single plugin, root source)
commands/
  expert.md            # Slash command: /expert on|off|<profile>
profiles/
  *.md                 # One persona per file (filename = profile slug)
hooks/
  hooks.json           # Registers SessionStart → session-start.sh
hooks-handlers/
  session-start.sh     # Loads mode file, builds additionalContext payload
context/
  <project-dir>.md     # Optional — loaded when cwd basename matches filename
data/
  expert-mode.txt      # Persisted mode: off | auto | <profile-slug>
docs/                  # Design notes and specs (not loaded at runtime)
```

## Critical behavior (do not break casually)

### SessionStart hook ([hooks-handlers/session-start.sh](hooks-handlers/session-start.sh))

1. Reads [data/expert-mode.txt](data/expert-mode.txt). Values: `off` (default behavior), `auto` (inject **all** profiles), or any `<slug>` matching `profiles/<slug>.md` (forced single profile).
2. If mode is **not** `off`, emits **valid JSON on stdout** with `additionalContext` containing:
   - The translation-engine instructions (embedded heredoc in the shell script)
   - All loaded profile bodies (Markdown)
   - Optional project context from `context/$(basename pwd).md` when that file exists
3. Uses `python3` to escape the concatenated Markdown for embedding in JSON (`json.dumps`).
4. Silent early-exit (`additionalContext`: `""`) when mode is `off`.

If you edit the heredoc or the JSON shape, you can brick every session that uses the plugin. Test by running the script with `MODE` manually or by toggling `/expert` and starting a new session.

### Slash command ([commands/expert.md](commands/expert.md))

- Writes the new mode to `data/expert-mode.txt`. Changes take effect on the **next** session (not the current one) — documented in command responses.
- Profile names MUST match **`profiles/<name>.md`** basename without `.md`.

### Profiles ([profiles/](profiles))

Each profile is Markdown with conventional sections mirroring existing files:

| Section | Purpose |
|---|---|
| **`#`** title | Display name |
| **`**Identity:**`** | One-line persona |
| **`## Domain Knowledge`** | Bulleted expertise anchors |
| **`## Translation Rules`** | Novice phrase → expert instructions |
| **`## Domain Signals (for auto-selection)`** | Comma-separated keyword list Claude uses when mode is `auto` |

Preserve this structure when adding or editing profiles so auto-selection stays predictable.

### Project context ([context/](context))

- File naming rule: **`context/<directory-basename>.md`** where `<directory-basename>` is `basename $(pwd)` on the user's machine — see naming in session-start script.
- When present, appended after profiles so translations reference concrete architecture instead of generic advice.

## Constraints

- **No network.** No telemetry, analytics, remote config, or version checks.
- **No committed secrets.** Profiles and context files describe patterns — never paste real credentials, URLs with tokens, or private data into this repo's `context/`examples.
- **Keep it dependency-free.** Do not introduce `node_modules`, `requirements.txt`, or compiled binaries. The design is deliberate: portable Markdown + a small shell/Python escape step.

## When you change something

- **New profile:** Add `profiles/<slug>.md` following the established section layout. Mention it in README's profile table only if you're changing the marketed set — the `/expert on` banner lists filenames dynamically.
- **Change translation rules (engine prompt):** Edit the `ENGINE_PROMPT` heredoc inside [hooks-handlers/session-start.sh](hooks-handlers/session-start.sh). Update [README.md](README.md) "How It Works" if user-visible behavior shifts.
- **Change mode persistence format:** Update both [commands/expert.md](commands/expert.md) and [hooks-handlers/session-start.sh](hooks-handlers/session-start.sh) to agree.
- **Plugin metadata:** Keep [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) and [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) in sync on `name`, `version`, and `description` if you bump versions.

## Testing

There is no CI. Manual checks:

1. `bash -n hooks-handlers/session-start.sh` — shell syntax
2. From repo root with `MODE=auto` simulated: run the hook script and pipe through `jq` to verify valid JSON (`jq empty <(./hooks-handlers/session-start.sh)` with mode file set — requires careful cwd)
3. In Claude Code: `/expert on`, new session, send a vague then a precise message and confirm translation vs pass-through matches the ENGINE_PROMPT rules
