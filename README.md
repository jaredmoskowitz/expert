<p align="center">
  <h1 align="center">expert</h1>
  <p align="center">
    <strong>You don't know what you don't know. Now you don't have to.</strong>
  </p>
  <p align="center">
    A Claude Code plugin that makes you sound like you know what you're talking about.
  </p>
  <p align="center">
    <a href="#install">Install</a> &#8226;
    <a href="#profiles">Profiles</a> &#8226;
    <a href="#add-your-own">Add Your Own</a> &#8226;
    <a href="LICENSE">MIT License</a>
  </p>
</p>

<p align="center">
  <img src="demo.gif" alt="Expert demo — translating novice input through domain experts" width="880">
</p>

---

## You say this:

```
"make it secure"
```

## Claude hears this:

> **Expert translation [security]:** Enumerate the attack surface using STRIDE.
> Check for: hardcoded secrets, missing input validation, auth flow gaps, overly
> broad permissions, unencrypted data at rest. Prioritize findings by severity
> (critical/high/medium) and likelihood. Flag any endpoints missing rate limiting
> or audit logging.

Then Claude acts on the expert version. Not yours.

---

## Why

AI agents do exactly what you ask. That's the problem.

| You say | What actually ships |
|---|---|
| "make it secure" | OWASP violations, hardcoded secrets |
| "add a users table" | No indexes, no rollback plan, no constraints |
| "write tests" | Mocks that test their own assumptions |
| "train a better model" | No baseline, no eval method, wrong metric |
| "it keeps crashing" | Random guesses instead of reading the logs |

You don't know what to ask for because you're not a domain expert. **Expert is.**

It sits between you and Claude. You speak plain english. Claude gets expert-level instructions. The translation is shown to you (so you learn over time) but doesn't slow you down.

---

## Install

Register the marketplace and install the plugin:

```bash
claude plugin marketplace add https://github.com/VeryLegit/expert
claude plugin install expert@expert
```

Restart Claude Code. Done.

---

## Usage

```
/expert on        # auto mode — picks the right expert(s) per message
/expert off       # back to normal
/expert security  # force a specific expert
/expert           # check status
```

That's it. Auto mode handles everything.

---

<h2 id="profiles">7 Built-in Experts</h2>

<table>
<tr>
<td width="150"><strong>Security</strong></td>
<td>

**You:** "add login"
**Expert:** Specify: auth protocol (OAuth 2.0/OIDC), session storage (httpOnly cookie vs JWT), token lifetime, revocation strategy, password policy, MFA consideration. What happens if the session token leaks?

</td>
</tr>
<tr>
<td><strong>Database</strong></td>
<td>

**You:** "add a users table"
**Expert:** Primary key strategy (UUID vs serial), required indexes on lookup columns, foreign key constraints, NOT NULL with defaults, migration rollback plan. What's the access pattern — read-heavy or write-heavy?

</td>
</tr>
<tr>
<td><strong>Testing</strong></td>
<td>

**You:** "write tests"
**Expert:** What behavior are we verifying? What are the failure modes that matter? What would a bug actually look like? Branch coverage on critical paths > line coverage everywhere.

</td>
</tr>
<tr>
<td><strong>Data/ML</strong></td>
<td>

**You:** "train a better model"
**Expert:** Define "better": which metric (AUC, F1, Brier), on what data split, vs what baseline, with what significance threshold? Check for data leakage and distribution shift first.

</td>
</tr>
<tr>
<td><strong>Systems</strong></td>
<td>

**You:** "it keeps crashing"
**Expert:** Identify category: OOM, unhandled exception, connection timeout, resource exhaustion, or dependency failure? Check structured logs first. What happens when this fails at 3 AM?

</td>
</tr>
<tr>
<td><strong>Frontend</strong></td>
<td>

**You:** "make it look better"
**Expert:** Identify the specific issue: layout (spacing, alignment), typography (hierarchy, readability), color (contrast, palette), or information hierarchy (what's prominent vs buried)?

</td>
</tr>
<tr>
<td><strong>Trading</strong></td>
<td>

**You:** "I think BTC is going up"
**Expert:** Evaluate signal strength on 15-min contracts. Check momentum features for directional bias. If metrics show quantifiable edge, propose a paper trade with Kelly sizing and drawdown constraints.

</td>
</tr>
</table>

---

## Auto-Selection

Expert picks the right specialist(s) for each message. Sometimes it blends two:

```
You: "show my risk exposure on the dashboard"

> Expert translation [trading + frontend]: Display a correlation matrix
> heatmap of active positions. Use a diverging color palette (red = high
> positive correlation, blue = negative). Annotate with position sizes
> and flag pairs above r=0.7 as concentrated exposure risk.
```

```
You: "add a users table with login"

> Expert translation [database + security]: Design the users table with
> UUID primary key, unique index on email, bcrypt-hashed password column
> (never plaintext), created_at/updated_at timestamps. Add a sessions
> table with token, expiry, and foreign key to users. Migration must be
> reversible. Specify: session token rotation policy and revocation on
> password change.
```

```
You: "read the main.py file"

(pass-through — no translation needed)
```

---

<h2 id="add-your-own">Add Your Own Expert</h2>

Drop a `.md` file in `profiles/`. That's the whole process.

```markdown
# DevOps & Cloud

**Identity:** Cloud infrastructure engineer with multi-cloud deployment expertise.

## Domain Knowledge

- **IaC:** Terraform state management, drift detection, module composition
- **Containers:** Multi-stage builds, health checks, resource limits, security scanning
- **CI/CD:** Pipeline design, secret injection, artifact promotion, rollback triggers

## Translation Rules

- "Deploy this" → specify: environment, rollback plan, health checks, monitoring, who gets paged
- "Set up CI" → specify: trigger conditions, test gates, secret management, artifact caching
- Always consider: what happens when this fails in production at 3 AM?

## Domain Signals (for auto-selection)

Keywords: deploy, CI, CD, pipeline, Docker, Kubernetes, Terraform, AWS, GCP, infrastructure
```

Save it. Restart. It just works.

---

## Project Context

Make translations reference **your** codebase, not generic advice.

Create `context/<your-project-name>.md`:

```markdown
# Project Context: my-app

## Architecture
- Next.js frontend, FastAPI backend, PostgreSQL database
- Deployed on Vercel (frontend) + Railway (backend)

## Key Files
- `api/routes/` — all API endpoints
- `lib/db.py` — database connection and queries

## Constraints
- All new features must have integration tests
- Database migrations must be reversible
```

When you `cd my-app` and use Claude Code, Expert automatically loads this context alongside the selected profiles. Your translations go from generic to surgical.

---

## How It Works

```
  You type something vague
           |
    /expert on? ──no──> normal Claude behavior
           |
          yes
           |
    Pick expert profile(s)
    based on message content
           |
    Translate through expert lens
           |
    Show translation as a note
           |
    Claude acts on expert version
```

It's a Claude Code plugin. A SessionStart hook loads the translation engine + all profiles into context. For each message, Claude picks the right expert(s), shows you the translation, and acts on it. Mode persists across sessions.

The entire thing is markdown files. No dependencies. No build step. No config.

---

## The Research

This isn't a guess. Meta-prompting works:

- **+18 percentage points** accuracy when one LLM refines another's input ([DSPy, Stanford](https://dspy.ai))
- **67% more time** spent debugging AI code when domain context is missing ([State of Software Delivery 2025](https://www.infoworld.com/article/4109129/ai-assisted-coding-creates-more-problems-report.html))
- The improvement is **largest for novice users** — exactly the use case
- ICLR 2025: [Meta-Prompt Optimization for Sequential Decision Making](https://iclr.cc/virtual/2025/32775)

---

<p align="center">
  <strong>MIT License</strong> &#8226; Built for <a href="https://claude.ai/code">Claude Code</a>
</p>
