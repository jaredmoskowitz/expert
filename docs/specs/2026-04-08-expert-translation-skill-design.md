# Expert Translation Skill — Design Spec

**Date:** 2026-04-08
**Status:** Draft
**Repo:** `~/workspace/expert` (publishable, usable locally)

## Problem

When non-experts describe what they want to AI coding agents, critical domain-specific details get lost. "Make it secure" ships with OWASP violations. "Add a users table" skips indexing and migration safety. "Write tests" produces boilerplate that tests assumptions, not edge cases. An intermediary "expert translator" reformulates novice input into precise, actionable directives before the agent acts — closing the gap between what you said and what an expert would have said.

## Solution

A Claude Code skill (`/expert`) that toggles an expert translation layer. When active, each user message is reformulated through domain expert personas before Claude acts on it. The skill ships with multiple pre-filled profiles and auto-selects (or blends) the right expert(s) based on the user's message context.

## Core Behavior

1. User sends a message
2. Skill assesses: does this benefit from expert translation, or is it a direct technical instruction?
3. If translation needed: auto-select the relevant profile(s) based on message content. May blend multiple profiles for cross-domain messages.
4. Reformulate using the selected expert(s)' domain knowledge and system context. Show as a brief `> **Expert translation:** ...` note. If multiple experts contributed, indicate which (e.g., `> **Expert translation [trading + frontend]:** ...`).
5. If ambiguous: ask ONE clarifying question using expert-level vocabulary and options grounded in the user's system.
6. Act on the translated version.

**Pass-through (no translation):** direct instructions like "read file X", "run tests", "commit this", or any message that's already precise and actionable.

## Toggle Commands

- `/expert` — show current status (on/off, active profile or auto mode)
- `/expert on` — activate in auto mode (smart profile selection per message)
- `/expert <profile>` — activate with a forced single profile (e.g., `/expert trading`)
- `/expert off` — deactivate

**Default mode is auto.** `/expert on` and `/expert trading` both activate the skill, but auto mode selects/blends profiles per message while a forced profile always uses that one lens.

## Expert Profile Structure

Each profile is a markdown file. Profiles contain:

### 1. Identity
Who the expert is — their background, perspective, and lens.

### 2. Domain Knowledge
Core concepts the expert brings to every translation. Not exhaustive — the key mental models and vocabulary.

### 3. System Context
Specific knowledge about the user's codebase and project. This is what makes translations actionable rather than generic.

### 4. Translation Rules
How to reformulate input:
- What to add (risk params, venue, timeframe, success criteria)
- What to preserve (user's core intent)
- When to ask vs. assume
- How to reference specific files/configs when actions map to the codebase

## Auto-Selection Logic

When in auto mode, the skill reads all available profiles and selects based on keyword/intent matching:

1. Scan user message for domain signals (trading terms, UI references, data/ML language, infra keywords)
2. Score each profile's relevance (0-1) based on overlap with the message
3. If one profile scores clearly highest → use it alone
4. If two+ profiles score meaningfully → blend them, noting which contributed
5. If no profile scores above threshold → pass through unchanged (it's a direct technical instruction)

**Examples:**
- "I think BTC is going up" → **trading** (directional opinion → testable hypothesis)
- "Make the dashboard show risk exposure" → **trading + frontend** (domain concept + UI implementation)
- "The engine keeps crashing on reconnect" → **systems** (reliability, error handling, reconnect strategy)
- "Train a better model for SOL" → **trading + data/ML** (signal theory + model evaluation methodology)
- "Is it safe to store the wallet key like this?" → **security** (secrets management, threat model)
- "Add a chart showing how correlated my positions are" → **trading + frontend** (correlation metrics + visualization design)
- "Add a users table" → **database** (schema design, indexes, migration safety)
- "Write tests for the engine" → **testing** (what failure modes matter, edge cases, test strategy)
- "Add a users table with login" → **database + security** (schema + auth flow + session storage)
- "Read the engine.py file" → **pass-through** (direct instruction)

## File Structure

```
~/workspace/expert/
  skill.md              — skill definition (toggle logic + translation engine + auto-selection)
  profiles/
    trading.md          — quant finance + market microstructure
    security.md         — application security + threat modeling
    data-ml.md          — ML pipelines + model evaluation
    systems.md          — infrastructure + reliability + deployment
    frontend.md         — UI/UX + data visualization + accessibility
    database.md         — schema design + migrations + query optimization
    testing.md          — test strategy + edge cases + QA methodology
  context/
    predickt.md         — predickt-specific system context
```

New profiles = new `.md` files in `profiles/`. No code changes needed.

## Pre-filled Profiles

### 1. Trading (trading.md)

**Identity:** Quantitative trading systems engineer with market microstructure expertise.

**Domain knowledge:**
- Position sizing (Kelly criterion, fractional Kelly, max drawdown constraints)
- Signal theory (alpha decay, edge quantification, false discovery rates)
- Risk management (correlation exposure, venue risk, slippage modeling)
- Market microstructure (order flow, latency, maker/taker dynamics)
- Backtesting methodology (walk-forward, out-of-sample, regime awareness)

**Translation rules:**
- Convert vague directional opinions into testable hypotheses
- Always specify: venue, timeframe, risk parameters, success criteria
- "Trade X" → evaluate signal viability first, not jump to execution
- "Make it faster" → identify specific bottleneck (polling interval, calibration window, threshold)
- "It's not working" → define what "working" means quantitatively (Sharpe, win rate, drawdown)

### 2. Security (security.md)

**Identity:** Application security engineer with offensive and defensive experience.

**Domain knowledge:**
- OWASP Top 10 and common vulnerability patterns
- Authentication/authorization (OAuth, JWT, session management, key rotation)
- Secrets management (environment variables, vaults, key derivation)
- API security (rate limiting, input validation, injection prevention)
- Threat modeling (attack surfaces, trust boundaries, data classification)
- Supply chain security (dependency auditing, lock files, provenance)

**Translation rules:**
- "Make it secure" → identify the specific attack surface and threat model
- "Add login" → specify auth flow, session handling, token storage, revocation strategy
- "Store the API key" → specify secrets management approach, rotation policy, access scope
- "Is this safe?" → enumerate specific risks with severity and likelihood
- Always flag: hardcoded secrets, missing input validation, overly broad permissions

### 3. Data/ML (data-ml.md)

**Identity:** ML engineer with expertise in applied machine learning and experiment methodology.

**Domain knowledge:**
- Model evaluation (cross-validation, calibration, proper scoring rules)
- Feature engineering (leakage detection, feature importance, collinearity)
- Experiment design (A/B testing, statistical significance, multiple comparisons)
- Data pipelines (ETL, schema evolution, data quality monitoring)
- Model deployment (versioning, monitoring, drift detection, rollback)
- Training methodology (expanding window, hyperparameter search, regularization)

**Translation rules:**
- "Train a better model" → define "better" (which metric, on what data split, vs what baseline)
- "Add a feature" → assess leakage risk, correlation with existing features, evaluation plan
- "The model is wrong" → distinguish calibration error, distribution shift, data quality, or label noise
- "Use deep learning" → justify complexity vs. baseline, assess data sufficiency
- Always specify: train/val/test split, evaluation metric, baseline comparison

### 4. Systems (systems.md)

**Identity:** Systems/infrastructure engineer with production reliability expertise.

**Domain knowledge:**
- Reliability (graceful degradation, circuit breakers, retry strategies, backpressure)
- Observability (structured logging, metrics, alerting, distributed tracing)
- Performance (profiling, bottleneck identification, caching strategies, concurrency)
- Deployment (blue/green, canary, rollback procedures, health checks)
- Networking (connection pooling, timeouts, DNS, TLS, WebSocket lifecycle)
- Process management (supervision, crash recovery, resource limits)

**Translation rules:**
- "It keeps crashing" → identify: is it OOM, unhandled exception, connection timeout, or resource exhaustion?
- "Make it faster" → profile first, identify whether it's CPU, I/O, network, or contention
- "Deploy this" → specify rollback plan, health checks, monitoring during rollout
- "Scale it" → horizontal vs vertical, stateless vs stateful, bottleneck identification
- Always consider: what happens when this fails at 3 AM with nobody watching?

### 5. Frontend (frontend.md)

**Identity:** Frontend engineer with UX and data visualization expertise.

**Domain knowledge:**
- Information hierarchy (what users need to see first, progressive disclosure)
- Data visualization (chart selection, color theory, axis scaling, annotation)
- Accessibility (WCAG, screen readers, keyboard navigation, color contrast)
- Performance (bundle size, lazy loading, render optimization, Core Web Vitals)
- Responsive design (breakpoints, mobile-first, touch targets)
- Component architecture (composition, state management, prop drilling avoidance)

**Translation rules:**
- "Make it look better" → identify: layout, typography, spacing, color, or information hierarchy?
- "Add a chart" → specify: what question does this answer? what comparison? what time range?
- "It's confusing" → identify the specific UX failure (overloaded view, missing context, poor labeling)
- "Make it responsive" → define breakpoints and what changes at each (hide, reflow, simplify)
- Always consider: what does the user need to decide based on this screen?

### 6. Database (database.md)

**Identity:** Database engineer with schema design and production migration expertise.

**Domain knowledge:**
- Schema design (normalization, denormalization trade-offs, indexing strategies)
- Migrations (rollback safety, zero-downtime migrations, backward compatibility)
- Query optimization (explain plans, index selection, N+1 detection, pagination)
- Data integrity (referential integrity, constraints, soft deletes, audit trails)
- Multi-tenancy (row-level security, schema isolation, shared-table patterns)
- Scaling patterns (read replicas, partitioning, connection pooling, caching layers)

**Translation rules:**
- "Add a table" → specify indexes, constraints, foreign keys, migration rollback plan
- "It's slow" → examine query plan, check for missing indexes, N+1 queries, full table scans
- "Delete old data" → soft delete vs hard delete, cascade implications, backup strategy
- "Add a column" → nullable vs default, backfill strategy, zero-downtime migration approach
- Always consider: what happens to existing data? can this migration be rolled back?

### 7. Testing (testing.md)

**Identity:** QA engineer with test strategy and reliability expertise.

**Domain knowledge:**
- Test strategy (unit vs integration vs e2e, testing pyramid, cost/value trade-offs)
- Edge cases (boundary values, error paths, race conditions, state transitions)
- Test design (arrange-act-assert, fixture management, deterministic tests)
- Coverage analysis (meaningful coverage vs vanity metrics, mutation testing)
- CI integration (flaky test detection, parallelization, test selection)
- Domain testing (property-based testing, contract testing, snapshot testing)

**Translation rules:**
- "Write tests" → what behavior are we verifying? what are the failure modes that matter?
- "It's flaky" → identify: timing dependency, shared state, external service, or ordering assumption?
- "Get more coverage" → coverage of what? branch coverage on critical paths > line coverage everywhere
- "Test the API" → contract tests for schema, integration tests for behavior, load tests for limits
- Always ask: what bug would this test catch? if the answer is "none specifically," reconsider

## Ambiguity Handling

When the expert can't confidently interpret the user's intent, it asks ONE clarifying question phrased with domain expertise. Not "what do you mean?" but specific options:

- "SOL on which venue — Kalshi 15-min or Polymarket 5-min? And are we evaluating signal quality first or going straight to paper?"
- "When you say 'more aggressive', do you mean lower the buy threshold (more trades, lower conviction) or increase position size (same trades, more capital at risk)?"

## Project-Specific Context Layer

Each profile contains domain-general knowledge. Optionally, a `context/` directory can hold project-specific context files that augment profiles when working in a specific codebase:

```
~/.claude/plugins/.../expert/
  context/
    predickt.md         — predickt-specific system context (engine architecture, key files, constraints)
```

When the skill detects it's in a project with a matching context file, that context is injected alongside the selected profile(s). This keeps profiles reusable across projects while still enabling deep codebase-aware translations.

**predickt.md context includes:**
- Fast engine: Kalshi 15-min + Polymarket 5-min crypto contracts
- Calibration: empirical, 30/90/180d rolling windows per symbol
- Architecture: ring buffers → signal generators → ML model → Kelly sizing → execution
- Current symbols: BTC, ETH, SOL
- Key files: `monte-carlo/fast/` for fast engine, `monte-carlo/ml/` for models
- Constraints: paper-first for new algorithms, $5 flat bets, limit orders only
- Dashboard: Next.js 16 + React 19 + Tailwind v4, FastAPI backend

## What This Is NOT

- Not an autonomous agent — it translates intent, Claude still does the work
- Not a prompt optimizer (DSPy-style) — it's domain expert personas, not statistical optimization
- Not always-on — explicit toggle, pass-through for technical instructions
- Not a separate system — it's a Claude Code skill, native to the existing workflow

## Success Criteria

- User can describe ideas in plain language and get translations that add the right domain-specific nuance without having to specify it themselves
- Auto-selection picks the right expert(s) without manual profile specification in the common case
- The translation is visible but non-blocking (shown as a note, no approval gate)
- Adding a new expert domain is just adding a `.md` file
- Adding project-specific context is just adding a file to `context/`
- Direct technical instructions pass through without unnecessary translation
