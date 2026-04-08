# Expert

**A domain-expert translation layer for Claude Code.**

You say what you want in plain language. Expert reformulates it through the right domain specialist before Claude acts — closing the gap between what you said and what an expert would have said.

---

## The Problem

When non-experts talk to AI coding agents, critical details get lost:

| What you say | What ships |
|---|---|
| "Make it secure" | OWASP violations, hardcoded secrets |
| "Add a users table" | No indexes, no migration rollback plan |
| "Write tests" | Boilerplate that tests assumptions, not edge cases |
| "Train a better model" | No baseline, no eval methodology, no significance test |
| "It keeps crashing" | Random fixes instead of profiling the actual bottleneck |

The domain expert in your head would have said something very different. Expert is that domain expert.

## How It Works

```
You:     "I think BTC is going up"
                  |
            Expert translates
                  |
Claude:  > Expert translation [trading]: Evaluate current BTC signal
         > strength on Kalshi 15-min contracts. Check OFI and VWAP
         > momentum features for directional bias. If metrics show
         > quantifiable edge, propose a paper trade with fractional
         > Kelly sizing and drawdown constraints. Define success
         > criteria: target win rate, minimum Sharpe, max drawdown.
                  |
            Claude acts on the translated version
```

Direct technical instructions ("read file X", "run tests", "commit this") pass through unchanged. Expert only activates when your message benefits from domain refinement.

## Install

```bash
# Clone the repo
git clone https://github.com/VeryLegit/expert.git

# Register as a Claude Code plugin
# Add to ~/.claude/plugins/installed_plugins.json:
{
  "expert@local": [{
    "scope": "user",
    "installPath": "/path/to/expert",
    "version": "1.0.0"
  }]
}

# Enable in ~/.claude/settings.json under enabledPlugins:
"expert@local": true
```

## Usage

```
/expert on              # auto mode (recommended) — picks the right expert(s) per message
/expert trading         # force a specific profile
/expert off             # disable
/expert                 # show status
```

**Auto mode** reads your message, selects the most relevant expert profile(s), and blends them if needed. You never have to think about which expert to use.

## Built-in Profiles

Seven domain experts ship out of the box:

### Trading & Quantitative Finance
> "I want to trade SOL" becomes "Evaluate SOL signal quality on Kalshi KXSOL15M. Check if calibration data covers SOL, assess OFI/VWAP features, and propose a paper trading pipeline with fractional Kelly sizing."

Covers: position sizing, signal theory, risk management, market microstructure, backtesting methodology, execution optimization.

### Application Security
> "Make it secure" becomes "Enumerate the attack surface using STRIDE. Identify: hardcoded secrets, missing input validation, auth flow gaps, overly broad permissions. Prioritize by severity and likelihood."

Covers: OWASP Top 10, auth/authz patterns, secrets management, API security, threat modeling, supply chain security.

### Data Science & ML
> "Train a better model" becomes "Define 'better': which metric (AUC, Brier, F1), on what data split, vs what baseline, with what significance threshold? Assess current model's calibration and check for distribution shift."

Covers: model evaluation, feature engineering, experiment design, data pipelines, drift detection, training methodology.

### Systems & Infrastructure
> "It keeps crashing" becomes "Identify category: OOM, unhandled exception, connection timeout, resource exhaustion, or dependency failure? Check structured logs first. What happens when this fails at 3 AM?"

Covers: reliability patterns, observability, performance profiling, deployment strategies, networking, process management.

### Frontend & UX
> "Make it look better" becomes "Identify the specific issue: layout (spacing, alignment), typography (hierarchy, readability), color (contrast, palette), or information hierarchy (what's prominent vs buried)?"

Covers: information hierarchy, data visualization, accessibility (WCAG), performance (Core Web Vitals), responsive design, component architecture.

### Database & Data Engineering
> "Add a users table" becomes "Specify: primary key strategy, required indexes, foreign keys, constraints, NOT NULL defaults, and migration rollback plan. What's the access pattern — read-heavy or write-heavy?"

Covers: schema design, migration safety, query optimization, data integrity, multi-tenancy, scaling patterns.

### Testing & QA
> "Write tests" becomes "What behavior are we verifying? What are the failure modes that matter? What would a bug actually look like? Branch coverage on critical paths > line coverage everywhere."

Covers: test strategy, edge case identification, test design patterns, coverage analysis, CI integration, specialized testing (property-based, contract, load).

## Auto-Selection & Blending

In auto mode, Expert reads your message and picks the right profile(s):

| Your message | Expert(s) selected |
|---|---|
| "I think BTC is going up" | **trading** |
| "Make the dashboard show risk exposure" | **trading + frontend** |
| "Is it safe to store the wallet key like this?" | **security** |
| "Train a better model for SOL" | **trading + data-ml** |
| "Add a users table with login" | **database + security** |
| "The engine keeps crashing on reconnect" | **systems** |
| "Read the engine.py file" | *pass-through* (no translation) |

When multiple profiles are relevant, the translation blends their perspectives:

```
> Expert translation [trading + frontend]: Display a correlation
> matrix heatmap of active positions using a diverging color palette
> (red for high positive, blue for negative). Include: pairwise
> Pearson correlation, position sizes as annotations, and a threshold
> line at r=0.7 to flag concentrated exposure.
```

## Add Your Own Profile

Drop a `.md` file in `profiles/`. That's it — no code changes needed.

```markdown
# Your Domain Name

**Identity:** Who this expert is and their background.

## Domain Knowledge

- **Topic area:** Key concepts, mental models, vocabulary
- **Another area:** More domain expertise

## Translation Rules

- "Vague thing users say" -> what the expert would specify instead
- "Another vague thing" -> precise, actionable reformulation
- Always consider: [what the expert never forgets to check]

## Domain Signals (for auto-selection)

Keywords: comma, separated, list, of, terms, that, trigger, this, profile
```

## Project Context

Make translations even more specific by adding project context. Create `context/<directory-name>.md` — when you're working in a directory with that name, the context is automatically injected alongside the selected profiles.

This lets profiles stay generic and reusable while translations reference your specific files, architecture, and constraints.

```markdown
# Project Context: my-project

## Architecture
- Key architectural decisions and patterns

## Key Files
- `src/engine.py` — what it does
- `src/models/` — what lives here

## Constraints
- Things the expert should always keep in mind
```

## Architecture

```
~/workspace/expert/
  .claude-plugin/plugin.json    # Plugin metadata
  commands/expert.md            # /expert toggle command
  hooks/hooks.json              # SessionStart hook registration
  hooks-handlers/session-start.sh  # Core: loads engine + profiles + context
  data/expert-mode.txt          # Persisted state (auto|off|<profile-name>)
  profiles/                     # Domain expert profiles (*.md)
    trading.md
    security.md
    data-ml.md
    systems.md
    frontend.md
    database.md
    testing.md
  context/                      # Project-specific context (*.md)
    predickt.md                 # Example: prediction market trading system
```

**How the pipeline works:**

1. `/expert on` writes `auto` to `data/expert-mode.txt`
2. At session start, `session-start.sh` reads the mode file
3. If active: loads the translation engine prompt + all profile files + matching project context into Claude's `additionalContext`
4. For each message, Claude auto-selects relevant profile(s), shows a brief translation note, then acts on the refined version
5. Mode persists across sessions until you `/expert off`

## Why This Works

Research backs it up:

- **Meta-prompting** (one LLM refining another's input) shows 18+ percentage point accuracy gains in benchmarks (DSPy, Stanford)
- The gap is **largest when the user is a novice** — exactly the use case
- An ICLR 2025 paper covers "Meta-Prompt Optimization for Sequential Decision Making" — directly applicable to trading and multi-step engineering tasks
- Teams spend **67% more time** debugging AI-generated code when domain context is missing (2025 State of Software Delivery)

Expert applies this research as a practical tool you can use today.

## License

MIT
