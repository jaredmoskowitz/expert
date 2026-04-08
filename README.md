# Expert

Expert translation layer for Claude Code. Reformulates novice user input through domain expert personas before Claude acts on it.

## What it does

When you toggle `/expert on`, every vague or novice message you send gets reformulated through a domain expert before Claude acts on it. Direct technical instructions pass through unchanged.

**Before:** "I think BTC is going up"
**After:**
> **Expert translation [trading]:** Evaluate current BTC signal strength across KXBTC15M (Kalshi 15-min) contracts. Check OFI and VWAP momentum features for directional bias. If signal metrics show quantifiable edge, propose a paper trade with position size derived from fractional Kelly and current drawdown constraints. Define success criteria: target win rate, minimum Sharpe, max acceptable drawdown.

## Install

```bash
claude plugin add /path/to/expert
```

## Usage

```
/expert on              # auto mode — picks the right expert(s) per message
/expert trading         # force a specific profile
/expert off             # disable
/expert                 # show status
```

## Built-in Profiles

| Profile | What it adds |
|---------|-------------|
| `trading` | Quantitative finance, market microstructure, risk management |
| `security` | OWASP, threat modeling, secrets management, auth flows |
| `data-ml` | ML evaluation methodology, feature engineering, experiment design |
| `systems` | Reliability, observability, performance, deployment |
| `frontend` | UX, data visualization, accessibility, component architecture |
| `database` | Schema design, migration safety, query optimization |
| `testing` | Test strategy, edge cases, meaningful coverage |

## Add Your Own

Drop a `.md` file in `profiles/`. No code changes needed. See existing profiles for the format.

## Project Context

Add project-specific knowledge by creating `context/<project-name>.md`. When you're in a directory matching that name, the context is automatically loaded alongside profiles.

## How it works

1. `/expert on` writes `auto` to a state file
2. At session start, a hook loads the translation engine + all profiles into Claude's context
3. For each message, Claude auto-selects the relevant profile(s), shows a brief translation note, then acts on the refined version
