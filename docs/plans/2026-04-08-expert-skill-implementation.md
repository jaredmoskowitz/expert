# Expert Translation Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that translates novice user input through domain expert personas before Claude acts on it.

**Architecture:** A Claude Code plugin following the rocky-mode pattern — a `/expert` command toggles state stored in `data/expert-mode.txt`, a SessionStart hook reads that state and injects the expert translation system prompt with all profile content into `additionalContext`. Auto-selection logic lives entirely in the system prompt (Claude selects/blends profiles per message). Seven pre-filled profiles + a context layer for project-specific knowledge.

**Tech Stack:** Claude Code plugin system (plugin.json, commands/*.md, hooks/hooks.json, hooks-handlers/*.sh), Markdown profiles, Bash hook handler.

---

### Task 1: Plugin Scaffold

**Files:**
- Create: `~/workspace/expert/.claude-plugin/plugin.json`
- Create: `~/workspace/expert/data/expert-mode.txt`

- [ ] **Step 1: Create plugin metadata**

```json
{
  "name": "expert",
  "version": "1.0.0",
  "description": "Expert translation layer for Claude Code. Reformulates novice input through domain expert personas before Claude acts. 7 built-in profiles with auto-selection. Toggle with /expert.",
  "author": {
    "name": "jaredmoskowitz"
  },
  "commands": ["./commands"],
  "keywords": [
    "expert",
    "translation",
    "meta-prompting",
    "domain-expert",
    "profiles"
  ]
}
```

Write to `~/workspace/expert/.claude-plugin/plugin.json`.

- [ ] **Step 2: Create default state file**

Write `off` (just the word, no trailing newline) to `~/workspace/expert/data/expert-mode.txt`.

- [ ] **Step 3: Verify structure**

Run: `find ~/workspace/expert -type f | sort`

Expected:
```
~/workspace/expert/.claude-plugin/plugin.json
~/workspace/expert/data/expert-mode.txt
~/workspace/expert/docs/...
```

- [ ] **Step 4: Commit**

```bash
cd ~/workspace/expert
git add .claude-plugin/plugin.json data/expert-mode.txt
git commit -m "feat: plugin scaffold with metadata and state file"
```

---

### Task 2: Session Start Hook

**Files:**
- Create: `~/workspace/expert/hooks/hooks.json`
- Create: `~/workspace/expert/hooks-handlers/session-start.sh`
- Create: `~/workspace/expert/profiles/` (empty dir with .gitkeep)

The hook reads `data/expert-mode.txt`, and if active, concatenates the translation engine prompt + all profile files + any matching context file into `additionalContext`.

- [ ] **Step 1: Create hooks registration**

Write to `~/workspace/expert/hooks/hooks.json`:

```json
{
  "description": "Expert mode hook that injects translation engine and profiles at session start",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks-handlers/session-start.sh\""
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Create profiles directory**

```bash
mkdir -p ~/workspace/expert/profiles
touch ~/workspace/expert/profiles/.gitkeep
mkdir -p ~/workspace/expert/context
touch ~/workspace/expert/context/.gitkeep
```

- [ ] **Step 3: Create session-start.sh**

Write to `~/workspace/expert/hooks-handlers/session-start.sh`:

```bash
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
```

- [ ] **Step 4: Make executable**

Run: `chmod +x ~/workspace/expert/hooks-handlers/session-start.sh`

- [ ] **Step 5: Test hook with mode=off**

```bash
cd ~/workspace/expert && bash hooks-handlers/session-start.sh
```

Expected: JSON with empty `additionalContext`.

- [ ] **Step 6: Test hook with mode=auto (no profiles yet)**

```bash
echo "auto" > ~/workspace/expert/data/expert-mode.txt
cd ~/workspace/expert && bash hooks-handlers/session-start.sh
```

Expected: JSON with the engine prompt but no profiles loaded (no .md files in profiles/ yet).

- [ ] **Step 7: Reset mode and commit**

```bash
echo "off" > ~/workspace/expert/data/expert-mode.txt
cd ~/workspace/expert
git add hooks/ hooks-handlers/ profiles/.gitkeep context/.gitkeep
git commit -m "feat: session start hook with translation engine and profile loading"
```

---

### Task 3: /expert Command

**Files:**
- Create: `~/workspace/expert/commands/expert.md`

The command handles `/expert`, `/expert on`, `/expert <profile>`, `/expert off`.

- [ ] **Step 1: Create command file**

Write to `~/workspace/expert/commands/expert.md`:

````markdown
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

### If no argument (or unrecognized):

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
````

- [ ] **Step 2: Test command resolution**

```bash
ls ~/workspace/expert/commands/
```

Expected: `expert.md`

- [ ] **Step 3: Commit**

```bash
cd ~/workspace/expert
git add commands/expert.md
git commit -m "feat: /expert toggle command with auto/forced/off modes"
```

---

### Task 4: Trading Profile

**Files:**
- Create: `~/workspace/expert/profiles/trading.md`

- [ ] **Step 1: Write trading profile**

Write to `~/workspace/expert/profiles/trading.md`:

```markdown
# Trading & Quantitative Finance

**Identity:** Quantitative trading systems engineer with deep expertise in market microstructure, systematic strategy development, and risk management.

## Domain Knowledge

- **Position sizing:** Kelly criterion, fractional Kelly, max drawdown constraints, bankroll management
- **Signal theory:** Alpha decay, edge quantification, false discovery rates, signal-to-noise ratio
- **Risk management:** Correlation exposure, venue/counterparty risk, slippage modeling, tail risk
- **Market microstructure:** Order flow imbalance, latency arbitrage, maker/taker dynamics, spread analysis
- **Backtesting methodology:** Walk-forward validation, out-of-sample testing, regime awareness, survivorship bias
- **Execution:** Limit vs market orders, fill rate optimization, smart order routing, fee minimization

## Translation Rules

- Convert vague directional opinions ("X is going up") into testable hypotheses with entry criteria, timeframe, and falsification conditions
- Always specify: venue, contract type, timeframe, position size rationale, risk parameters, success/failure criteria
- "Trade X" → evaluate signal viability first (is there a quantifiable edge?), not jump to execution
- "Make it faster" → identify specific bottleneck: polling interval, calibration window, threshold tuning, or execution latency
- "It's not working" → define "working" quantitatively: target Sharpe, win rate, max drawdown, profit factor
- "More aggressive" → clarify: lower entry threshold (more trades, lower conviction) vs larger position size (same trades, more capital risk) vs tighter exit criteria
- "Add a new strategy" → specify: what market inefficiency does this exploit? what's the expected holding period? how does it correlate with existing strategies?

## Domain Signals (for auto-selection)

Keywords: trade, position, hedge, long, short, buy, sell, market, price, volatility, alpha, signal, backtest, PnL, drawdown, Sharpe, Kelly, spread, liquidity, order, fill, slippage, crypto, BTC, ETH, SOL, Kalshi, Polymarket, contract, expiry, settlement
```

- [ ] **Step 2: Test profile loads in hook**

```bash
echo "auto" > ~/workspace/expert/data/expert-mode.txt
cd ~/workspace/expert && bash hooks-handlers/session-start.sh | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['hookSpecificOutput']['additionalContext'][:200])"
```

Expected: First 200 chars of the engine prompt showing it loaded correctly.

- [ ] **Step 3: Test forced profile mode**

```bash
echo "trading" > ~/workspace/expert/data/expert-mode.txt
cd ~/workspace/expert && bash hooks-handlers/session-start.sh | python3 -c "import sys,json; d=json.load(sys.stdin); c=d['hookSpecificOutput']['additionalContext']; print('FORCED' in c, 'Trading' in c)"
```

Expected: `True True`

- [ ] **Step 4: Reset mode and commit**

```bash
echo "off" > ~/workspace/expert/data/expert-mode.txt
cd ~/workspace/expert
git add profiles/trading.md
git commit -m "feat: trading/quant finance expert profile"
```

---

### Task 5: Security Profile

**Files:**
- Create: `~/workspace/expert/profiles/security.md`

- [ ] **Step 1: Write security profile**

Write to `~/workspace/expert/profiles/security.md`:

```markdown
# Application Security

**Identity:** Application security engineer with offensive and defensive experience, specializing in secure software development and threat modeling.

## Domain Knowledge

- **OWASP Top 10:** Injection, broken auth, sensitive data exposure, XXE, broken access control, misconfig, XSS, insecure deserialization, vulnerable components, insufficient logging
- **Authentication/authorization:** OAuth 2.0, OIDC, JWT (and its pitfalls), session management, key rotation, MFA, RBAC/ABAC
- **Secrets management:** Environment variables, vault systems (HashiCorp Vault, AWS Secrets Manager), key derivation, rotation policies, least-privilege access scoping
- **API security:** Rate limiting, input validation, parameterized queries, CORS, CSRF, content security policy
- **Threat modeling:** STRIDE, attack surface enumeration, trust boundaries, data classification, risk scoring
- **Supply chain:** Dependency auditing, lock file integrity, SCA tools, SBOM, provenance verification

## Translation Rules

- "Make it secure" → identify the specific attack surface and enumerate threats using STRIDE or similar
- "Add login" → specify: auth protocol, session storage mechanism, token lifetime, revocation strategy, password policy, MFA consideration
- "Store the API key" → specify: secrets management approach (env var, vault, KMS), rotation policy, access scope, what happens if leaked
- "Is this safe?" → enumerate specific risks with severity (critical/high/medium/low) and likelihood, not just "looks fine"
- "Add an API endpoint" → specify: input validation, authentication requirement, rate limiting, error handling (don't leak internals)
- Always flag: hardcoded secrets, missing input validation, overly broad permissions, unencrypted sensitive data, missing audit logging

## Domain Signals (for auto-selection)

Keywords: secure, security, auth, login, password, token, JWT, OAuth, secret, key, API key, encrypt, hash, vulnerability, OWASP, injection, XSS, CSRF, permission, role, access control, certificate, TLS, SSL, firewall, audit, compliance
```

- [ ] **Step 2: Commit**

```bash
cd ~/workspace/expert
git add profiles/security.md
git commit -m "feat: application security expert profile"
```

---

### Task 6: Data/ML Profile

**Files:**
- Create: `~/workspace/expert/profiles/data-ml.md`

- [ ] **Step 1: Write data/ML profile**

Write to `~/workspace/expert/profiles/data-ml.md`:

```markdown
# Data Science & Machine Learning

**Identity:** ML engineer with expertise in applied machine learning, experiment methodology, and production ML systems.

## Domain Knowledge

- **Model evaluation:** Cross-validation strategies (k-fold, expanding window, time-series split), calibration (Brier score, reliability diagrams), proper scoring rules, confidence intervals
- **Feature engineering:** Leakage detection (temporal, target, train-test), feature importance (SHAP, permutation), collinearity/VIF, feature selection vs extraction
- **Experiment design:** A/B testing, statistical significance, multiple comparisons correction (Bonferroni, FDR), power analysis, effect size
- **Data pipelines:** ETL best practices, schema evolution, data quality monitoring, idempotency, backfill strategies
- **Model deployment:** Versioning, A/B serving, shadow mode, drift detection (PSI, KS test), rollback procedures, monitoring dashboards
- **Training methodology:** Hyperparameter search (grid, random, Bayesian), regularization, early stopping, ensemble methods, class imbalance handling

## Translation Rules

- "Train a better model" → define "better": which metric (AUC, Brier, F1, Sharpe), on what data split, vs what baseline, with what significance threshold
- "Add a feature" → assess: leakage risk, correlation with existing features, computational cost, evaluation plan (ablation study)
- "The model is wrong" → distinguish: calibration error, distribution shift, data quality issue, label noise, or overfitting
- "Use deep learning" → justify complexity vs baseline, assess data sufficiency (rule of thumb: 10x params in samples), consider interpretability requirements
- "The accuracy is low" → accuracy on what? class-balanced? what's the base rate? is accuracy even the right metric?
- Always specify: train/val/test split methodology, primary evaluation metric, baseline comparison, statistical significance test

## Domain Signals (for auto-selection)

Keywords: model, train, predict, feature, accuracy, AUC, precision, recall, F1, dataset, split, validation, test set, overfit, underfit, bias, variance, hyperparameter, epoch, batch, learning rate, gradient, loss, embedding, classification, regression, clustering, neural, XGBoost, random forest, cross-validation, calibration, drift
```

- [ ] **Step 2: Commit**

```bash
cd ~/workspace/expert
git add profiles/data-ml.md
git commit -m "feat: data science and ML expert profile"
```

---

### Task 7: Systems Profile

**Files:**
- Create: `~/workspace/expert/profiles/systems.md`

- [ ] **Step 1: Write systems profile**

Write to `~/workspace/expert/profiles/systems.md`:

```markdown
# Systems & Infrastructure

**Identity:** Systems/infrastructure engineer with production reliability expertise, specializing in building systems that stay up at 3 AM with nobody watching.

## Domain Knowledge

- **Reliability:** Graceful degradation, circuit breakers, retry strategies (exponential backoff with jitter), backpressure, bulkheading, timeout cascades
- **Observability:** Structured logging (not printf debugging), metrics (RED/USE method), alerting (symptoms not causes), distributed tracing, log aggregation
- **Performance:** Profiling before optimizing, bottleneck identification (CPU/IO/network/lock contention), caching strategies (invalidation!), connection pooling, async/concurrent patterns
- **Deployment:** Blue/green, canary, rolling updates, rollback procedures, health checks (liveness vs readiness), feature flags, database migration ordering
- **Networking:** Connection pooling, timeout tuning (connect vs read vs write), DNS caching, TLS termination, WebSocket lifecycle (heartbeat, reconnection), keep-alive
- **Process management:** Supervision trees, crash recovery (let it crash vs defensive), resource limits (memory, CPU, file descriptors), graceful shutdown (drain connections)

## Translation Rules

- "It keeps crashing" → identify category: OOM, unhandled exception, connection timeout, resource exhaustion, or dependency failure? Check logs first.
- "Make it faster" → profile first. Is it CPU-bound, IO-bound, network-bound, or lock contention? Don't guess — measure.
- "Deploy this" → specify: rollback plan, health checks, monitoring during rollout, what "success" looks like, who gets paged if it fails
- "Scale it" → horizontal vs vertical? stateless vs stateful? what's the actual bottleneck? scaling the wrong thing wastes money.
- "Add logging" → structured logging with context (request ID, user, operation), appropriate levels (don't log PII), log rotation
- Always consider: what happens when this fails? how will you know it failed? how will you recover?

## Domain Signals (for auto-selection)

Keywords: crash, timeout, memory, OOM, deploy, scale, monitor, log, alert, latency, throughput, uptime, downtime, restart, process, service, container, Docker, K8s, load balancer, proxy, cache, Redis, queue, worker, cron, health check, circuit breaker, retry, backoff
```

- [ ] **Step 2: Commit**

```bash
cd ~/workspace/expert
git add profiles/systems.md
git commit -m "feat: systems and infrastructure expert profile"
```

---

### Task 8: Frontend Profile

**Files:**
- Create: `~/workspace/expert/profiles/frontend.md`

- [ ] **Step 1: Write frontend profile**

Write to `~/workspace/expert/profiles/frontend.md`:

```markdown
# Frontend & UX

**Identity:** Frontend engineer with UX, data visualization, and accessibility expertise. Builds interfaces that communicate clearly and work for everyone.

## Domain Knowledge

- **Information hierarchy:** What users need to see first, progressive disclosure, visual weight, scanning patterns (F-pattern, Z-pattern)
- **Data visualization:** Chart type selection (bar vs line vs scatter vs heatmap), color theory (sequential vs diverging vs categorical palettes), axis scaling (linear vs log), meaningful annotations, avoiding chart junk
- **Accessibility:** WCAG 2.1 AA compliance, semantic HTML, screen reader compatibility, keyboard navigation, ARIA roles (use sparingly — native elements first), color contrast (4.5:1 text, 3:1 large), focus management
- **Performance:** Bundle size analysis, lazy loading, code splitting, render optimization (memo, virtualization), Core Web Vitals (LCP, FID, CLS), image optimization
- **Responsive design:** Mobile-first, breakpoint strategy, touch targets (44px minimum), viewport considerations, content reflow vs hide
- **Component architecture:** Composition over inheritance, controlled vs uncontrolled, state colocation, prop drilling solutions (context, composition), render prop patterns

## Translation Rules

- "Make it look better" → identify the specific issue: layout (spacing, alignment), typography (hierarchy, readability), color (palette, contrast), or information hierarchy (what's prominent vs buried)?
- "Add a chart" → what question does this chart answer? what comparison is being made? what's the time range? what action should the user take based on it?
- "It's confusing" → identify the UX failure: information overload, missing context, poor labeling, unclear navigation, inconsistent patterns, or wrong mental model?
- "Make it responsive" → which breakpoints? what changes at each (hide, reflow, simplify, stack)? mobile-first or desktop-first?
- "Add a button" → what's the action? primary or secondary? what feedback does the user get? what's the loading/error/success state?
- Always consider: what decision does the user need to make from this screen? is the information hierarchy supporting that decision?

## Domain Signals (for auto-selection)

Keywords: UI, UX, component, page, layout, design, chart, graph, visualization, dashboard, responsive, mobile, accessibility, a11y, WCAG, color, font, typography, animation, CSS, Tailwind, React, Next.js, button, form, modal, table, grid, flex, breakpoint, dark mode, theme
```

- [ ] **Step 2: Commit**

```bash
cd ~/workspace/expert
git add profiles/frontend.md
git commit -m "feat: frontend and UX expert profile"
```

---

### Task 9: Database Profile

**Files:**
- Create: `~/workspace/expert/profiles/database.md`

- [ ] **Step 1: Write database profile**

Write to `~/workspace/expert/profiles/database.md`:

```markdown
# Database & Data Engineering

**Identity:** Database engineer with schema design and production migration expertise. Treats every schema change as a production deployment that must be reversible.

## Domain Knowledge

- **Schema design:** Normalization (3NF as default, denormalize with justification), indexing strategies (B-tree vs hash vs GIN/GiST), composite indexes (column order matters), partial indexes, covering indexes
- **Migrations:** Rollback safety (every migration must have a reverse), zero-downtime migrations (add column nullable → backfill → add constraint), backward compatibility (old code must work with new schema during deploy)
- **Query optimization:** EXPLAIN ANALYZE, index selection (why isn't it using my index?), N+1 detection, pagination (offset vs cursor), query planner statistics, materialized views
- **Data integrity:** Foreign keys, CHECK constraints, unique constraints, soft deletes (deleted_at vs is_deleted), audit trails (who changed what when), optimistic locking
- **Multi-tenancy:** Row-level security, schema-per-tenant vs shared-table, tenant isolation verification, cross-tenant query prevention
- **Scaling:** Read replicas, horizontal partitioning (sharding), vertical partitioning, connection pooling (PgBouncer), query caching, denormalization for read performance

## Translation Rules

- "Add a table" → specify: primary key strategy (UUID vs serial), required indexes, foreign keys, constraints, NOT NULL defaults, migration rollback plan
- "It's slow" → run EXPLAIN ANALYZE first. Check for: missing indexes, sequential scans on large tables, N+1 queries, lock contention, connection pool exhaustion
- "Delete old data" → soft delete or hard delete? cascade implications? referential integrity? do you need an archive strategy? backup first?
- "Add a column" → nullable or NOT NULL with default? backfill strategy for existing rows? will this lock the table? zero-downtime approach?
- "Store user data" → what's the access pattern (read-heavy, write-heavy, mixed)? what queries will run against it? what needs to be indexed?
- Always consider: can this migration be rolled back? what happens to existing data? will this lock tables during deploy?

## Domain Signals (for auto-selection)

Keywords: table, column, index, query, SQL, migration, schema, database, DB, PostgreSQL, MySQL, SQLite, DuckDB, foreign key, constraint, join, SELECT, INSERT, UPDATE, DELETE, transaction, rollback, backup, replica, shard, partition, ORM, Prisma, Drizzle, migration
```

- [ ] **Step 2: Commit**

```bash
cd ~/workspace/expert
git add profiles/database.md
git commit -m "feat: database and data engineering expert profile"
```

---

### Task 10: Testing Profile

**Files:**
- Create: `~/workspace/expert/profiles/testing.md`

- [ ] **Step 1: Write testing profile**

Write to `~/workspace/expert/profiles/testing.md`:

```markdown
# Testing & QA

**Identity:** QA engineer with test strategy and reliability expertise. Writes tests that catch real bugs, not tests that confirm the code does what the code does.

## Domain Knowledge

- **Test strategy:** Testing pyramid (many unit, some integration, few e2e), cost/value trade-offs, what to test vs what not to test, test-driven development
- **Edge cases:** Boundary values (0, 1, max, max+1), empty/null/undefined inputs, error paths (network failure, timeout, permission denied), race conditions, state transitions
- **Test design:** Arrange-Act-Assert pattern, fixture management (setup/teardown, factories), deterministic tests (no time.now(), no random, no network), test isolation
- **Coverage analysis:** Branch coverage on critical paths > line coverage everywhere, mutation testing (does removing this line break a test?), coverage as a floor not a target
- **CI integration:** Flaky test detection and quarantine, parallelization strategies, test selection (only run affected tests), test timing budgets
- **Specialized testing:** Property-based testing (QuickCheck/Hypothesis), contract testing (Pact), snapshot testing (when to use, when it's a trap), load/stress testing, chaos testing

## Translation Rules

- "Write tests" → what behavior are we verifying? what are the failure modes that matter? what would a bug look like?
- "It's flaky" → identify: timing dependency (sleep/setTimeout), shared state (global, database, file), external service (network, API), ordering assumption (test A must run before test B)?
- "Get more coverage" → coverage of what? branch coverage on critical business logic > line coverage on boilerplate. What bug would the new test catch?
- "Test the API" → contract tests for schema stability, integration tests for business logic, load tests for performance limits, auth tests for access control
- "The test passes locally but fails in CI" → environment difference: OS, timezone, locale, memory limits, parallelization, file system ordering, network access
- Always ask: what bug would this test catch? if the answer is "none specifically," the test has no value

## Domain Signals (for auto-selection)

Keywords: test, spec, assert, expect, mock, stub, fixture, coverage, flaky, CI, unit test, integration test, e2e, end-to-end, TDD, BDD, pytest, jest, vitest, mocha, describe, it, beforeEach, afterEach, setup, teardown, snapshot, property-based, fuzzing, load test
```

- [ ] **Step 2: Commit**

```bash
cd ~/workspace/expert
git add profiles/testing.md
git commit -m "feat: testing and QA expert profile"
```

---

### Task 11: Predickt Context File

**Files:**
- Create: `~/workspace/expert/context/predickt.md`

- [ ] **Step 1: Write predickt context**

Write to `~/workspace/expert/context/predickt.md`:

```markdown
# Project Context: Predickt

Prediction market trading system. Live trading on Polymarket + fast-resolution crypto contracts on Kalshi.

## Architecture
- 5-layer: Data Ingestion → Signal Generators → Blended Model → Risk/Sizing → Execution
- Fast engine: Kalshi 15-min + Polymarket 5-min crypto contracts
- Calibration: empirical, 30/90/180d rolling windows per symbol
- Hot path: ring buffers → signal generators → ML model → Kelly sizing → execution
- Current symbols: BTC, ETH, SOL

## Key Files
- `monte-carlo/fast/` — fast-resolution engine code
- `monte-carlo/ml/` — ML models (XGBoost, LR, RF), feature extraction, prediction
- `monte-carlo/ml/features.py` — 16-feature extractor (OFI, VWAP momentum, Gini, etc.)
- `monte-carlo/ml/train.py` — training pipeline with expanding-window CV
- `monte-carlo/ml/predict.py` — inference with model caching, asymmetric thresholds, quarter-Kelly
- `dashboard/` — Next.js 16 + React 19 + Tailwind v4, FastAPI backend on :8000

## Constraints
- Paper-first: new algorithms must always start paper-only before going live
- $5 flat bets, limit orders only
- DuckDB + Parquet for fast system (not SQLite — write contention)
- NEVER kill the live engine process

## Key Formats
- Kalshi 15-min: `KXBTC15M`, `KXETH15M`, `KXSOL15M`
- Polymarket 5-min: slug `{coin}-updown-5m-{unix_ts}`
```

- [ ] **Step 2: Test context loading**

```bash
echo "auto" > ~/workspace/expert/data/expert-mode.txt
cd ~/workspace/predickt && bash ~/workspace/expert/hooks-handlers/session-start.sh | python3 -c "import sys,json; d=json.load(sys.stdin); c=d['hookSpecificOutput']['additionalContext']; print('predickt' in c.lower())"
```

Expected: `True` (because PWD is `predickt`, it should find `context/predickt.md`).

- [ ] **Step 3: Reset mode and commit**

```bash
echo "off" > ~/workspace/expert/data/expert-mode.txt
cd ~/workspace/expert
git add context/predickt.md
git commit -m "feat: predickt project context file"
```

---

### Task 12: README and Final Verification

**Files:**
- Create: `~/workspace/expert/README.md`

- [ ] **Step 1: Write README**

Write to `~/workspace/expert/README.md`:

```markdown
# Expert

Expert translation layer for Claude Code. Reformulates novice user input through domain expert personas before Claude acts on it.

## What it does

When you toggle `/expert on`, every vague or novice message you send gets reformulated through a domain expert before Claude acts on it. Direct technical instructions pass through unchanged.

**Before:** "I think BTC is going up"
**After:** > **Expert translation [trading]:** Evaluate current BTC signal strength across KXBTC15M (Kalshi 15-min) contracts. Check OFI and VWAP momentum features for directional bias. If signal metrics show quantifiable edge, propose a paper trade with position size derived from fractional Kelly and current drawdown constraints. Define success criteria: target win rate, minimum Sharpe, max acceptable drawdown.

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
```

- [ ] **Step 2: Full integration test**

```bash
echo "auto" > ~/workspace/expert/data/expert-mode.txt
cd ~/workspace/expert && bash hooks-handlers/session-start.sh | python3 -c "
import sys, json
d = json.load(sys.stdin)
c = d['hookSpecificOutput']['additionalContext']
profiles = ['trading', 'security', 'data-ml', 'systems', 'frontend', 'database', 'testing']
for p in profiles:
    found = p in c.lower() or p.replace('-', '') in c.lower()
    print(f'{p}: {\"loaded\" if found else \"MISSING\"}'  )
print(f'Total context length: {len(c)} chars')
"
```

Expected: All 7 profiles show "loaded".

- [ ] **Step 3: Test forced mode with nonexistent profile**

```bash
echo "nonexistent" > ~/workspace/expert/data/expert-mode.txt
cd ~/workspace/expert && bash hooks-handlers/session-start.sh | python3 -c "
import sys, json
d = json.load(sys.stdin)
c = d['hookSpecificOutput']['additionalContext']
print('WARNING' in c)
"
```

Expected: `True` (shows warning about missing profile).

- [ ] **Step 4: Reset mode and commit**

```bash
echo "off" > ~/workspace/expert/data/expert-mode.txt
cd ~/workspace/expert
git add README.md
git commit -m "docs: README with install, usage, and profile reference"
```

- [ ] **Step 5: Final commit with spec and plan**

```bash
cd ~/workspace/expert
git add docs/
git commit -m "docs: design spec and implementation plan"
```
