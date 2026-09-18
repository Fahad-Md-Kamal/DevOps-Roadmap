---
title: Delivery Principles
icon: lucide/compass
---

# Delivery Principles & Process

## 01 Principles & SDLC

### 1.1 The Three Ways (Flow, Feedback, Continual Learning)

This mental model, from Gene Kim's *The Phoenix Project* and *Accelerate*, underpins everything in DevOps.

#### The First Way — Flow (left to right)

Work moves from development to production with no long queues, no invisible work, and small batch sizes instead of giant releases. The goal is to shorten the time between a developer writing code and that code delivering value to a user.

Key practices:

- Small, frequent commits rather than large, infrequent releases
- Automated testing so the pipeline doesn't stall waiting for manual QA
- Limiting work in progress so tasks finish rather than pile up
- Making work visible — everyone can see what's in progress, blocked, or done

#### The Second Way — Feedback (right to left)

Signals move from production back to development, fast. A failing test, a production alert, a customer complaint — the shorter the path back to the person who can fix it, the cheaper the fix. A bug caught in a developer's IDE costs minutes; the same bug caught in production costs hours, customer trust, and possibly money.

- Automated monitoring and alerting on production systems
- Fast test suites that run on every commit
- Blameless post-incident reviews that produce systemic fixes
- Telemetry everywhere — you can't improve what you can't measure

#### The Third Way — Continual Learning and Experimentation

A culture of experimentation, where every incident becomes shared knowledge rather than blame. Teams run game days (simulated failures), conduct chaos engineering, and turn every post-mortem into a concrete improvement. Every improvement becomes the new baseline you build on.

- Blameless post-mortems with action items that actually get implemented
- Allocated time for improvement work (not just feature work)
- Sharing knowledge across teams through documentation and internal talks
- Experimentation — new tools, approaches, architectures in low-risk settings first

### 1.2 DORA Metrics

Four measurements from the DevOps Research and Assessment group, validated across thousands of organizations. They split into two speed metrics and two stability metrics.

| Metric | What it measures | Elite | High | Medium | Low |
|---|---|---|---|---|---|
| **Deployment frequency** | How often you ship to production | On demand (multiple/day) | Weekly–monthly | Monthly–semi-annually | < once / 6 months |
| **Lead time for changes** | Time from commit to production | < 1 hour | 1 day – 1 week | 1 week – 1 month | > 6 months |
| **Change failure rate** | % of deployments causing a failure | 0–15% | 16–30% | 16–30% | 16–30% |
| **Time to restore service** | How fast you recover from an incident | < 1 hour | < 1 day | 1 day – 1 week | > 6 months |

!!! success "Critical insight"

    **Speed and stability are not a trade-off.** Elite teams are good at both simultaneously. Shipping faster doesn't mean more failures — it means smaller changes that are easier to debug and roll back.

#### How to measure each one practically

- **Deployment frequency:** count of production deploys from Jenkins/pipeline build history
- **Lead time:** timestamp of PR merge to timestamp of production deploy
- **Change failure rate:** count of rollbacks or hotfixes divided by total deploys
- **Time to restore:** duration from incident alert to service recovery, from incident tickets

### 1.3 SLIs, SLOs, and Error Budgets

SLI — Service Level Indicator
:   A measured quantity that describes some aspect of service health, e.g. "99.95% of HTTP requests returned a 2xx/3xx status", "p95 latency was 220ms", "99.99% of scheduled cron jobs completed successfully".

SLO — Service Level Objective
:   The target for an SLI, agreed with the team and (ideally) the business, e.g. "99.9% of requests succeed over a rolling 30-day window" or "p95 latency stays below 300ms".

Error budget
:   The gap between 100% and your SLO. A 99.9% SLO leaves a 0.1% error budget — roughly 43 minutes of downtime per month. This budget is "spent" on risk: deploys, experiments, maintenance.

#### How error budgets drive decisions

- Budget remaining → ship features, take risks, experiment
- Budget almost exhausted → slow down, focus on reliability, skip risky deploys
- Budget exceeded → freeze feature work, all effort goes to stability until it recovers

This turns "reliability" from a vague feeling into a number the engineering team and the business can make decisions with — and it prevents the trap where ops says "we can never deploy, it might break things." The error budget explicitly permits a certain amount of breakage.

### 1.4 Toil vs Engineering Work

!!! danger "Toil"

    Manual, repetitive, automatable work that scales linearly with the system and has no lasting value — SSH-ing in to restart a service, copying config to every server by hand, checking disk usage each morning, manually creating IAM users via the console.

!!! success "Engineering work"

    Reduces toil or adds durable value — a script that restarts a crashed service automatically, a CI/CD pipeline that deploys config changes, CloudWatch alarms for disk usage, Terraform that provisions IAM users from config.

Google's SRE guidance: cap toil at 50% of a team's time. If you're doing the same manual step three times, it should become a script or pipeline stage by the fourth time.

**The practical test:** "If the system doubles in size, does this task also double?" If yes, it's toil. If no (because it's automated), it's engineering.

### 1.5 Scrum and Kanban Applied to a Platform Backlog

Infrastructure work splits into two fundamentally different streams:

- **Planned work (~60%):** build the VPC, set up CI/CD, migrate the database to RDS, write Terraform modules — predictable, estimable, fits sprint-style planning.
- **Unplanned work (~40%):** production is down, a dev team needs a new IAM role, a security patch dropped today, disk is 95% full — arrives any time, can't wait for the next sprint.

!!! danger "Pure Scrum breaks"

    Scrum assumes most work is planned and committed to a sprint. When 40% arrives unpredictably, sprint commitments are constantly blown and the process becomes a burden.

!!! danger "Pure Kanban's cost"

    Continuous flow handles interrupts naturally, but without sprint commitments, long-term project work gets endlessly deprioritized behind whoever is shouting loudest.

#### The hybrid most DevOps teams actually use

- Scrum-style 1-week sprints for planned project work (sprint goal: "VPC and IAM roles are built and documented")
- Kanban board running alongside for operational requests and incidents, with its own WIP limits
- Sprint capacity planned at 60% to absorb interrupt-driven work — pull extra backlog tasks if no incidents come
- One standup covers both streams: "Here's my sprint task. I also picked up an incident yesterday, here's the status."

**WIP limits:** a maximum number of items per board stage — e.g. 2 per person "In Progress." Uncomfortable, but the first two finish faster; context-switching between three half-done incidents is slower than finishing two sequentially.

**Cycle time** replaces velocity as the metric: how long does a task take from "Ready" to "Done"? Growing cycle time means something is blocking flow.

#### Definition of Done for infrastructure

1. Works end-to-end — the VPC actually routes traffic, the IAM role actually grants access
2. Reproducible — built via code, not clicked in the console
3. Secure — least-privilege, no open access, encrypted
4. Documented — a teammate can understand it without asking you
5. Explains trade-offs — you can articulate what you chose and what you rejected

### 1.6 Shift-Left Testing and Security

"Shift left" means moving testing and security checks earlier in the pipeline — towards the developer's commit, away from the end.

``` shift right — expensive
Code → Build → Deploy to staging → Manual QA → Security audit → Deploy to prod
                                                  ↑ bug found here costs days
```

``` shift left — cheap
Code → Lint + unit tests → SAST scan → Build → Deploy to staging → Prod
 ↑ bug found here costs minutes
```

#### Concrete shift-left practices

- **Pre-commit hooks:** linting, formatting, basic checks before the commit even enters Git
- **Unit tests on every commit:** CI fails immediately if tests break
- **SAST:** tools like Bandit (Python), Semgrep, or Checkov (Terraform) scan for security issues in code, on the PR
- **Dependency scanning:** Dependabot or Snyk check for known vulnerabilities in libraries before deploy
- **Policy-as-code:** Open Policy Agent (OPA) enforces rules like "no S3 buckets without encryption" at the PR level

The principle: the earlier you catch a problem, the cheaper it is to fix. A SQL injection caught by SAST during code review costs 15 minutes. The same vulnerability caught in a production penetration test costs days of remediation, an incident report, and possibly a breach.

### 1.7 Trunk-Based Development

**The model:** everyone commits to (or near) a single `main` branch frequently, using short-lived feature branches that live for hours to at most a couple of days.

``` trunk-based
main:    ──●──●──●──●──●──●──●──●──●──  (always deployable)
              \  /   \  /       \  /
feature-a:    ●──●   (merged in hours)
feature-b:         ●──●──●     (merged in 1-2 days max)
```

!!! danger "Rejected alt."

    ``` gitflow
    main:       ──●────────────────●──────  (only release merges)
    develop:    ──●──●──●──●──●──●──●──●──  (integration branch)
    release/1.2:         ●──●──●          (release branch)
    feature-xyz:    ●──●──●──●──●──●──●   (weeks-long branches)
    ```

#### Why trunk-based wins for DevOps

- Short-lived branches mean fewer merge conflicts (hours of drift, not weeks)
- `main` is always in a deployable state — any commit can be released
- Enables small-batch, high-frequency deployment (daily or multiple times a day)
- Forces code to be backward-compatible (it's going to main alongside other work)

**How incomplete work ships safely:** feature flags. Code is deployed "dark" — it exists in production but is behind a flag that's off. Enable it for internal users first, then 1%, then 10%, then 100%. If something breaks, disable the flag — no redeploy needed.

**Manager's likely challenge:** "But Gitflow gives you a clear release branch — how do you handle hotfixes in trunk-based?"

**Your defense:** a hotfix is just another fast merge to main, deployed immediately. No cherry-picking across branches, no "which branch has the fix" confusion. Feature flags mean the fix ships in minutes, not hours.

### 1.8 Modern Change Management

!!! danger "Traditional — slow"

    A Change Advisory Board (CAB) meets weekly, reviews every proposed change, approves or rejects. Changes queue for the next meeting. Deployment frequency: at best weekly, often monthly.

#### Modern approach — fast and safe

- **Small changes:** small diffs are easier to review, understand, and roll back
- **Peer review:** a pull request reviewed by a teammate, not a committee meeting
- **Automated gates:** the CI pipeline enforces tests, security scans, and policy checks — passing the pipeline means meeting the quality bar
- **Fast rollback path:** the safety net is not a meeting; it's the ability to revert in minutes

This doesn't mean no governance — it means governance is encoded in the pipeline rather than performed in a meeting. The pipeline is stricter than a CAB (checks every change, not a sample) and faster (seconds, not days).


## 02 Deployment & Multi-Region

### 2.1 Deployment Strategies — In Depth

#### 2.1.1 Recreate

!!! note "Mechanism"

    ```
    [v1 running] → [v1 stopped — DOWNTIME] → [v2 starting] → [v2 running]
    ```

!!! danger "Failure mode"

    If v2 fails to start (bad config, crash loop, missing dependency), nothing is running. Recovery means redeploying v1 — another outage cycle. Total outage duration is unpredictable.

!!! note "Cost"

    Cheapest — you only ever run one set of infrastructure. No duplicate environments, no traffic splitting, no weighted routing.

!!! success "Use when"

    Internal tools with a maintenance window, batch processing jobs, dev/staging environments where downtime doesn't matter. Never for user-facing production services.

#### 2.1.2 Rolling

!!! note "Mechanism"

    ```
    Step 1: [v2] [v1] [v1] [v1]    ← 1 replaced, 3 still serving on v1
    Step 2: [v2] [v2] [v1] [v1]    ← 2 replaced
    Step 3: [v2] [v2] [v2] [v1]    ← 3 replaced
    Step 4: [v2] [v2] [v2] [v2]    ← done (~10 minutes total)
    ```

!!! danger "Failure — mixed versions"

    Both v1 and v2 serve traffic simultaneously. The load balancer distributes randomly. If v2 changes an API response format, or expects a DB column v1 doesn't create, you get inconsistent behaviour.

!!! danger "Failure — slow rollback"

    If v2 is bad, you do another rolling deploy back to v1 — which takes just as long. You've been serving bad responses the whole time.

!!! note "Cost"

    Low — never more than N instances total (briefly N-1 mid-swap while one drains).

!!! note "Gate"

    Health check passed (binary: up or down). No metrics analysis, no baseline comparison. Automatic and fast.

!!! success "Use when"

    Stateless services where v1 and v2 are backward-compatible. Read-heavy APIs where a mixed-version window is tolerable.

#### 2.1.3 Blue/Green

!!! note "Mechanism"

    ```
    Before: Load balancer → Blue (v1) [4 instances]    Green (v2) [4 instances, idle]
    Switch: Load balancer → Green (v2) [4 instances]   Blue (v1) [4 instances, idle]
    After:  Terminate Blue once confident Green is stable (hours/days later)
    ```

!!! danger "Failure — full blast radius"

    100% of traffic hits v2 instantly on switch. No gradual ramp. A subtle bug appearing only at full load or with real data hits every user at once. Rollback is fast, but the blast radius before you notice is 100%.

!!! note "Cost"

    Highest — double infrastructure during the switchover window. At scale (40 servers), you run 80 during deploy. Blue must stay alive for confidence (hours or a full day).

!!! success "Use when"

    You need instant, clean rollback. Databases and stateful services where a slow rollback is unaffordable. Frontend assets (new S3 path, switch CloudFront origin — zero mixed versions).

**Key advantage over rolling:** no mixed-version window. Traffic goes entirely to v1 or entirely to v2, never both — matters for services with strict API contract requirements.

#### 2.1.4 Canary

!!! note "Mechanism"

    ```
    Stage 1: [v2: 5%]  [v1: 95%]    ← watch for 30 min, compare metrics
    Stage 2: [v2: 25%] [v1: 75%]    ← watch for 30 min at higher load
    Stage 3: [v2: 100%]              ← done (~2 hours total)
    ```

!!! danger "Failure — monitoring blindness"

    Canary is only as good as your observability. If your dashboard can't detect a 5% error increase (noisy baseline), the bug slips through and you promote to 25%. The gate requires meaningful monitoring.

!!! danger "Failure — data corruption"

    If the canary writes corrupt data for 5% of users, rolling back the traffic doesn't undo the data damage.

!!! note "Cost"

    Low to moderate — instances are replaced in place (like rolling), so server count stays the same. The extra cost is monitoring/observability tooling that makes traffic-split decisions meaningful.

!!! note "Gate"

    Metrics comparison — is v2's error rate, p99 latency, and business metrics comparable to v1's baseline? Analysis, not just a health check — often human judgment or automated anomaly detection, with deliberate 15–60 min pauses between steps.

!!! success "Use when"

    Anything where the blast radius of a bad deploy is expensive — payment services, order processing, authentication. You're trading deployment speed for safety.

**Difference from rolling:** same in-place infrastructure approach, but fundamentally different in speed and decision logic. Rolling replaces automatically in ~10 minutes with only a health-check gate. Canary takes ~2 hours with deliberate pauses and metrics comparison. Rolling asks "is it alive?"; canary asks "is it behaving correctly?"

#### 2.1.5 Shadow (Dark Launch)

!!! note "Mechanism"

    Production traffic is duplicated — the real request goes to v1 (which serves the actual response), and a copy goes to v2 (which processes it but its response is discarded). You compare v2's outputs and performance against v1's.

!!! danger "Failure — write side effects"

    Works well for reads (compare search results, recommendations). Dangerous for writes — if v2 processes a duplicated payment request, you've double-charged someone. You must mock all write side effects or only shadow read paths.

!!! danger "Failure — resource doubling"

    Doubles compute and network load. Downstream dependencies (databases, external APIs) receive double the traffic and may not be provisioned for it.

!!! note "Cost"

    High — two full environments and double the compute for every request.

!!! success "Use when"

    Major refactors needing proof the new system produces identical results. ML model deployment (shadow the new model, compare predictions). Database migration (compare query results between old and new databases).

### 2.2 Feature Flags as a Deployment Tool

Feature flags decouple **deployment** (code goes to production) from **release** (users see the feature):

``` python
# In your Django view
def checkout_view(request):
    if feature_flags.is_enabled('new_checkout_flow', user=request.user):
        return new_checkout(request)     # new code, deployed but dark
    else:
        return old_checkout(request)     # existing code, all users see this
```

You deploy this to 100% of instances via a simple rolling deploy. Nobody sees the new checkout yet. Then you flip the flag for 1% of users — a canary release with no infrastructure change. Ramp to 10%, 50%, 100%. If it breaks, flip it off — instant, no redeploy.

!!! success "Why it matters"

    Feature flags let you use simple, cheap rolling deploys for most changes while still getting canary-like safety for risky features. You don't need blue/green infrastructure to get blue/green-like control.

#### The cost of feature flags

- Code complexity — branches everywhere, multiple paths to maintain
- Stale flags — "temporary" flags accumulate if not cleaned up
- Testing burden — you need to test both flag-on and flag-off paths
- Discipline required — every flag needs an owner, a purpose, and an expiry date

#### Flag types

- **Release flags:** temporary, control rollout of a new feature, removed after full rollout
- **Ops flags:** semi-permanent, disable expensive features under load ("circuit breakers")
- **Experiment flags:** A/B testing, comparing user behaviour between variants
- **Permission flags:** long-lived, control feature access by user tier (free vs paid)

### 2.3 Backward-Compatible Schema Migrations

**The rule:** never make a database change that breaks the currently running version of your app. During a rolling deploy, v1 and v2 run simultaneously against the same database. If v2's migration drops a column v1 still reads, v1 crashes.

#### The expand-and-contract pattern — three separate deploys

Deploy 1 — Expand
:   Add the new column (e.g. `full_name`) alongside the old ones. App code dual-writes to both, reads from old columns. v1 still works — it ignores the new column. Safe to roll back: redeploy v1, the new column sits there unused.

Deploy 2 — Migrate
:   Backfill `full_name` for all existing rows. Switch app code to read from the new column. Continue dual-writing. If this fails, old columns still have valid data — safe to roll back.

Deploy 3 — Contract (days or weeks later)
:   Stop writing to the old columns, drop them from the schema. This is the point of no return — after this you can't roll back to the old app version.

In your Django experience, you might run `makemigrations` and `migrate` in a single deploy. In production DevOps, the migration and the app deploy are separate events with days between them.

!!! danger "Avoid"

    - `DROP COLUMN` in the same deploy that stops reading from it
    - `RENAME COLUMN` (old code can't find the column under the new name)
    - `ALTER COLUMN` to a narrower type (e.g. VARCHAR(255) → VARCHAR(50) — longer existing data gets truncated)
    - Adding a NOT NULL constraint without a default (existing rows fail the constraint)

### 2.4 Why Rollback Is Usually a Lie

Everyone says "we can just roll back." Here's why it's almost never that simple:

Scenario 1 — Schema has moved forward
:   v2 ran a migration adding a NOT NULL column. v1's code doesn't write to it. Rolling back means new rows violate the constraint — writes crash.

Scenario 2 — Data format has changed
:   v2 started writing addresses in a new JSON structure. v1 expects the old structure and can't parse what v2 wrote while it was live.

Scenario 3 — External state has changed
:   v2 sent emails, processed payments, published events. You can roll back your code, but you can't un-send emails or un-charge cards.

Scenario 4 — Dependent services have moved forward
:   v2 of service A started sending a new field that service B now depends on. Rolling back service A breaks service B.

#### What real rollback requires

- A reverse migration script that safely undoes schema changes
- A data migration that converts v2-written data back to v1's format
- Identification of every external side effect and a remediation plan for each
- Testing the rollback path before you need it (which almost nobody does)

!!! success "Honest framing"

    Rollback is a forward fix that happens to use the previous version's code. Treat it as a deployment, not an undo button. Plan for it explicitly, test it, and document what it won't fix.

### 2.5 Pipeline Anatomy

#### Build once, promote everywhere (correct)

```
Build (image:abc123) → Dev (abc123) → Staging (abc123) → Prod (abc123)
                                                          ↑ SAME artifact
```

The CI server builds an image (or JAR, or zip) once, tags it with the commit hash, pushes it to a registry (ECR). That exact, immutable artifact is deployed to dev, promoted to staging, promoted to prod. What changes between environments is **configuration**, injected at runtime — env vars, secrets from Secrets Manager, connection strings from Parameter Store. The artifact itself is byte-for-byte identical.

#### Rebuild per stage (anti-pattern)

```
Build #1 (image:aaa111) → Dev     Build #2 (image:bbb222) → Prod
                                   ↑ DIFFERENT artifact — never tested
```

!!! danger "Why it's dangerous"

    Builds are not perfectly reproducible. A `pip install` might pull a newer patch version. An `apt-get update` might include a security patch that changes behaviour. A timestamp or random seed might differ. You've deployed something to production that's never been tested anywhere, even though the source is identical.

#### What may legitimately differ between environments

| Aspect | Must be same | May differ |
|---|---|---|
| Container image / artifact | ✓ |  |
| Deployment pipeline and process | ✓ |  |
| Configuration mechanism (env vars from Secrets Manager) | ✓ |  |
| Instance size (t3.small vs m5.xlarge) |  | ✓ |
| Replica count (1 vs 4) |  | ✓ |
| Database (shared dev RDS vs Multi-AZ prod RDS) |  | ✓ |
| External integrations (Stripe sandbox vs live) |  | ✓ |
| Data (synthetic vs anonymized copy vs real) |  | ✓ |
| Monitoring depth (basic vs full + PagerDuty) |  | ✓ |

**The rule:** the deployment mechanism and the artifact must be identical. Scale, cost, data, and external integration endpoints may differ — those are economics and safety, not correctness.

#### Environment tiers and their purpose

Dev
:   Auto-deploys on merge to `main`. Fast integration feedback. Minimal resources, shared database, synthetic data. If it breaks, nobody outside the team notices.

Staging
:   Deploys on promotion from dev (manual trigger or automated after dev smoke tests pass). Catches configuration and integration bugs that only appear at near-production configuration. Same secrets-path structure and deployment process as prod, similar (smaller) infrastructure, sandboxed external services.

Production
:   Deploys after manual approval gate from staging. Real users, real data, real money. Full monitoring, PagerDuty alerts, Multi-AZ databases, auto-scaling enabled.

**Why three tiers, not two:** staging catches problems that only appear at prod-like configuration — wrong env vars, misconfigured secrets, connection pool limits, IAM mismatches. Without staging, your first prod-like test is production itself.

### 2.6 Multi-Region Architecture

#### Active-Active

Both regions serve live traffic simultaneously. Users route to the closest region by latency (Route 53 latency-based routing).

```
Route 53 (latency-based routing)
├── ap-south-1 — ACTIVE (serving traffic, read-write DB)
└── eu-west-1 — ACTIVE (serving traffic, read-write DB)
    ↕ bi-directional data replication
```

!!! success "Advantages"

    - Near-zero RTO — if one region fails, the other is already serving traffic; DNS just stops sending traffic there
    - Lower latency for geographically distributed users
    - Full utilization of both regions (no idle infrastructure)

!!! danger "Challenges"

    - **Data conflicts:** simultaneous updates to the same record in different regions need conflict resolution (last-write-wins, application merge logic, CRDTs)
    - **Cost:** double infrastructure, all the time (not just during deploys)
    - **Complexity:** every service must be region-aware, every write must replicate, every cache synchronized or independently warmed

#### Active-Passive

One region serves all traffic. A second sits on standby with a read replica and the ability to be promoted on failure.

```
Route 53 (failover routing)
├── ap-south-1 — ACTIVE (all traffic, primary read-write DB)
└── eu-west-1 — STANDBY (no traffic, read replica, promoted on failure)
    → one-way async replication
```

!!! success "Advantages"

    - Simpler — no data conflict resolution needed
    - Cheaper — standby runs minimal infrastructure (DB replica, maybe a cold ASG)
    - Sufficient for most businesses that can tolerate minutes of downtime

!!! danger "Challenges"

    - **Failover time:** promoting standby, warming instances, updating DNS takes 15–30 minutes typically
    - **Standby rot:** untested failover may not work when needed — run failover drills quarterly
    - **Data loss:** async replication means the standby is always slightly behind — the gap is your RPO

#### Traffic steering (Route 53 routing policies)

- **Latency-based:** routes to whichever region has the lowest latency. Used in active-active.
- **Failover:** primary/secondary record with a health check; if primary fails, DNS resolves to secondary. Used in active-passive.
- **Geolocation:** routes by country/continent — data residency compliance (EU users → EU region).
- **Weighted:** sends X% to one region, Y% to another — gradual region migration.

#### RTO and RPO

These are business decisions that you implement technically.

RTO — Recovery Time Objective
:   Maximum acceptable downtime. "We cannot be down more than 30 minutes" → RTO 30 minutes. Drives your DR architecture choice.

RPO — Recovery Point Objective
:   Maximum acceptable data loss, in time. "We can lose at most 5 minutes of data" → RPO 5 minutes. Drives your replication strategy.

| Target | Architecture | Replication | Cost |
|---|---|---|---|
| RTO 4hr, RPO 24hr | Backups in another region, restore on failure | Daily backup snapshots | Low |
| RTO 30min, RPO 5min | Active-passive, async replication | Continuous async (seconds of lag) | Moderate |
| RTO ~0, RPO ~0 | Active-active, sync replication | Synchronous (adds write latency) | Very high |

**The honest business conversation:** "You want zero downtime and zero data loss. That costs 2.5x your current infrastructure budget and adds 40ms latency to every write. Are you sure you don't mean 30 minutes and 5 minutes?" Usually, they do.


