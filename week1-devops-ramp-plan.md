# Delivery Principles & AWS Foundations
*Assignment A1 · Strategy Document*

Defend a deployment strategy and environment topology, and build a correctly designed AWS network by hand with least-privilege IAM roles.

**Required deliverables**

1. Branching model and release cadence, with the rejected alternative
2. Deployment-strategy decision matrix by service class
3. Environment and promotion diagram
4. Multi-region topology with RTO and RPO
5. DORA baseline and targets
6. Three IAM roles with least-privilege justification
7. VPC architecture diagram with CIDR plan

---

## Principles & SDLC
*DevOps Principles and the SDLC*

### 1.1 The Three Ways (Flow, Feedback, Continual Learning)

This mental model, from Gene Kim's _The Phoenix Project_ and _Accelerate_, underpins everything in DevOps.

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
| --- | --- | --- | --- | --- | --- |
| **Deployment frequency** | How often you ship to production | On demand (multiple/day) | Weekly–monthly | Monthly–semi-annually | < once / 6 months |
| **Lead time for changes** | Time from commit to production | < 1 hour | 1 day – 1 week | 1 week – 1 month | > 6 months |
| **Change failure rate** | % of deployments causing a failure | 0–15% | 16–30% | 16–30% | 16–30% |
| **Time to restore service** | How fast you recover from an incident | < 1 hour | < 1 day | 1 day – 1 week | > 6 months |

> **Critical insight**
>
> **Speed and stability are not a trade-off.** Elite teams are good at both simultaneously. Shipping faster doesn't mean more failures — it means smaller changes that are easier to debug and roll back.

#### How to measure each one practically

- **Deployment frequency:** count of production deploys from Jenkins/pipeline build history
- **Lead time:** timestamp of PR merge to timestamp of production deploy
- **Change failure rate:** count of rollbacks or hotfixes divided by total deploys
- **Time to restore:** duration from incident alert to service recovery, from incident tickets

### 1.3 SLIs, SLOs, and Error Budgets

- **SLI — Service Level Indicator** — A measured quantity that describes some aspect of service health, e.g. "99.95% of HTTP requests returned a 2xx/3xx status", "p95 latency was 220ms", "99.99% of scheduled cron jobs completed successfully".

- **SLO — Service Level Objective** — The target for an SLI, agreed with the team and (ideally) the business, e.g. "99.9% of requests succeed over a rolling 30-day window" or "p95 latency stays below 300ms".

- **Error budget** — The gap between 100% and your SLO. A 99.9% SLO leaves a 0.1% error budget — roughly 43 minutes of downtime per month. This budget is "spent" on risk: deploys, experiments, maintenance.

#### How error budgets drive decisions

- Budget remaining → ship features, take risks, experiment
- Budget almost exhausted → slow down, focus on reliability, skip risky deploys
- Budget exceeded → freeze feature work, all effort goes to stability until it recovers

This turns "reliability" from a vague feeling into a number the engineering team and the business can make decisions with — and it prevents the trap where ops says "we can never deploy, it might break things." The error budget explicitly permits a certain amount of breakage.

### 1.4 Toil vs Engineering Work

> **Toil**
>
> Manual, repetitive, automatable work that scales linearly with the system and has no lasting value — SSH-ing in to restart a service, copying config to every server by hand, checking disk usage each morning, manually creating IAM users via the console.

> **Engineering work**
>
> Reduces toil or adds durable value — a script that restarts a crashed service automatically, a CI/CD pipeline that deploys config changes, CloudWatch alarms for disk usage, Terraform that provisions IAM users from config.

Google's SRE guidance: cap toil at 50% of a team's time. If you're doing the same manual step three times, it should become a script or pipeline stage by the fourth time.

**The practical test:** "If the system doubles in size, does this task also double?" If yes, it's toil. If no (because it's automated), it's engineering.

### 1.5 Scrum and Kanban Applied to a Platform Backlog

Infrastructure work splits into two fundamentally different streams:

- **Planned work (~60%):** build the VPC, set up CI/CD, migrate the database to RDS, write Terraform modules — predictable, estimable, fits sprint-style planning.
- **Unplanned work (~40%):** production is down, a dev team needs a new IAM role, a security patch dropped today, disk is 95% full — arrives any time, can't wait for the next sprint.

> **Pure Scrum breaks**
>
> Scrum assumes most work is planned and committed to a sprint. When 40% arrives unpredictably, sprint commitments are constantly blown and the process becomes a burden.

> **Pure Kanban's cost**
>
> Continuous flow handles interrupts naturally, but without sprint commitments, long-term project work gets endlessly deprioritized behind whoever is shouting loudest.

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

_shift right — expensive_
```
Code → Build → Deploy to staging → Manual QA → Security audit → Deploy to prod
                                                  ↑ bug found here costs days
```

_shift left — cheap_
```
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

_trunk-based_
```
main:    ──●──●──●──●──●──●──●──●──●──  (always deployable)
              \  /   \  /       \  /
feature-a:    ●──●   (merged in hours)
feature-b:         ●──●──●     (merged in 1-2 days max)
```

> **Rejected alt.**
>
> _gitflow_
> ```
> main:       ──●────────────────●──────  (only release merges)
> develop:    ──●──●──●──●──●──●──●──●──  (integration branch)
> release/1.2:         ●──●──●          (release branch)
> feature-xyz:    ●──●──●──●──●──●──●   (weeks-long branches)
> ```

#### Why trunk-based wins for DevOps

- Short-lived branches mean fewer merge conflicts (hours of drift, not weeks)
- `main` is always in a deployable state — any commit can be released
- Enables small-batch, high-frequency deployment (daily or multiple times a day)
- Forces code to be backward-compatible (it's going to main alongside other work)

**How incomplete work ships safely:** feature flags. Code is deployed "dark" — it exists in production but is behind a flag that's off. Enable it for internal users first, then 1%, then 10%, then 100%. If something breaks, disable the flag — no redeploy needed.

> **Manager's likely challenge:** "But Gitflow gives you a clear release branch — how do you handle hotfixes in trunk-based?"
>
> **Your defense:** a hotfix is just another fast merge to main, deployed immediately. No cherry-picking across branches, no "which branch has the fix" confusion. Feature flags mean the fix ships in minutes, not hours.

### 1.8 Modern Change Management

> **Traditional — slow**
>
> A Change Advisory Board (CAB) meets weekly, reviews every proposed change, approves or rejects. Changes queue for the next meeting. Deployment frequency: at best weekly, often monthly.

#### Modern approach — fast and safe

- **Small changes:** small diffs are easier to review, understand, and roll back
- **Peer review:** a pull request reviewed by a teammate, not a committee meeting
- **Automated gates:** the CI pipeline enforces tests, security scans, and policy checks — passing the pipeline means meeting the quality bar
- **Fast rollback path:** the safety net is not a meeting; it's the ability to revert in minutes

This doesn't mean no governance — it means governance is encoded in the pipeline rather than performed in a meeting. The pipeline is stricter than a CAB (checks every change, not a sample) and faster (seconds, not days).

## Deployment & Multi-Region
*Deployment Strategies, Environments & Multi-Region*

### 2.1 Deployment Strategies — In Depth

#### 2.1.1 Recreate

> **Mechanism**
>
> ```
> [v1 running] → [v1 stopped — DOWNTIME] → [v2 starting] → [v2 running]
> ```

> **Failure mode**
>
> If v2 fails to start (bad config, crash loop, missing dependency), nothing is running. Recovery means redeploying v1 — another outage cycle. Total outage duration is unpredictable.

> **Cost**
>
> Cheapest — you only ever run one set of infrastructure. No duplicate environments, no traffic splitting, no weighted routing.

> **Use when**
>
> Internal tools with a maintenance window, batch processing jobs, dev/staging environments where downtime doesn't matter. Never for user-facing production services.

#### 2.1.2 Rolling

> **Mechanism**
>
> ```
> Step 1: [v2] [v1] [v1] [v1]    ← 1 replaced, 3 still serving on v1
> Step 2: [v2] [v2] [v1] [v1]    ← 2 replaced
> Step 3: [v2] [v2] [v2] [v1]    ← 3 replaced
> Step 4: [v2] [v2] [v2] [v2]    ← done (~10 minutes total)
> ```

> **Failure — mixed versions**
>
> Both v1 and v2 serve traffic simultaneously. The load balancer distributes randomly. If v2 changes an API response format, or expects a DB column v1 doesn't create, you get inconsistent behaviour.

> **Failure — slow rollback**
>
> If v2 is bad, you do another rolling deploy back to v1 — which takes just as long. You've been serving bad responses the whole time.

> **Cost**
>
> Low — never more than N instances total (briefly N-1 mid-swap while one drains).

> **Gate**
>
> Health check passed (binary: up or down). No metrics analysis, no baseline comparison. Automatic and fast.

> **Use when**
>
> Stateless services where v1 and v2 are backward-compatible. Read-heavy APIs where a mixed-version window is tolerable.

#### 2.1.3 Blue/Green

> **Mechanism**
>
> ```
> Before: Load balancer → Blue (v1) [4 instances]    Green (v2) [4 instances, idle]
> Switch: Load balancer → Green (v2) [4 instances]   Blue (v1) [4 instances, idle]
> After:  Terminate Blue once confident Green is stable (hours/days later)
> ```

> **Failure — full blast radius**
>
> 100% of traffic hits v2 instantly on switch. No gradual ramp. A subtle bug appearing only at full load or with real data hits every user at once. Rollback is fast, but the blast radius before you notice is 100%.

> **Cost**
>
> Highest — double infrastructure during the switchover window. At scale (40 servers), you run 80 during deploy. Blue must stay alive for confidence (hours or a full day).

> **Use when**
>
> You need instant, clean rollback. Databases and stateful services where a slow rollback is unaffordable. Frontend assets (new S3 path, switch CloudFront origin — zero mixed versions).

**Key advantage over rolling:** no mixed-version window. Traffic goes entirely to v1 or entirely to v2, never both — matters for services with strict API contract requirements.

#### 2.1.4 Canary

> **Mechanism**
>
> ```
> Stage 1: [v2: 5%]  [v1: 95%]    ← watch for 30 min, compare metrics
> Stage 2: [v2: 25%] [v1: 75%]    ← watch for 30 min at higher load
> Stage 3: [v2: 100%]              ← done (~2 hours total)
> ```

> **Failure — monitoring blindness**
>
> Canary is only as good as your observability. If your dashboard can't detect a 5% error increase (noisy baseline), the bug slips through and you promote to 25%. The gate requires meaningful monitoring.

> **Failure — data corruption**
>
> If the canary writes corrupt data for 5% of users, rolling back the traffic doesn't undo the data damage.

> **Cost**
>
> Low to moderate — instances are replaced in place (like rolling), so server count stays the same. The extra cost is monitoring/observability tooling that makes traffic-split decisions meaningful.

> **Gate**
>
> Metrics comparison — is v2's error rate, p99 latency, and business metrics comparable to v1's baseline? Analysis, not just a health check — often human judgment or automated anomaly detection, with deliberate 15–60 min pauses between steps.

> **Use when**
>
> Anything where the blast radius of a bad deploy is expensive — payment services, order processing, authentication. You're trading deployment speed for safety.

**Difference from rolling:** same in-place infrastructure approach, but fundamentally different in speed and decision logic. Rolling replaces automatically in ~10 minutes with only a health-check gate. Canary takes ~2 hours with deliberate pauses and metrics comparison. Rolling asks "is it alive?"; canary asks "is it behaving correctly?"

#### 2.1.5 Shadow (Dark Launch)

> **Mechanism**
>
> Production traffic is duplicated — the real request goes to v1 (which serves the actual response), and a copy goes to v2 (which processes it but its response is discarded). You compare v2's outputs and performance against v1's.

> **Failure — write side effects**
>
> Works well for reads (compare search results, recommendations). Dangerous for writes — if v2 processes a duplicated payment request, you've double-charged someone. You must mock all write side effects or only shadow read paths.

> **Failure — resource doubling**
>
> Doubles compute and network load. Downstream dependencies (databases, external APIs) receive double the traffic and may not be provisioned for it.

> **Cost**
>
> High — two full environments and double the compute for every request.

> **Use when**
>
> Major refactors needing proof the new system produces identical results. ML model deployment (shadow the new model, compare predictions). Database migration (compare query results between old and new databases).

### 2.2 Feature Flags as a Deployment Tool

Feature flags decouple **deployment** (code goes to production) from **release** (users see the feature):

```python
# In your Django view
def checkout_view(request):
    if feature_flags.is_enabled('new_checkout_flow', user=request.user):
        return new_checkout(request)     # new code, deployed but dark
    else:
        return old_checkout(request)     # existing code, all users see this
```

You deploy this to 100% of instances via a simple rolling deploy. Nobody sees the new checkout yet. Then you flip the flag for 1% of users — a canary release with no infrastructure change. Ramp to 10%, 50%, 100%. If it breaks, flip it off — instant, no redeploy.

> **Why it matters**
>
> Feature flags let you use simple, cheap rolling deploys for most changes while still getting canary-like safety for risky features. You don't need blue/green infrastructure to get blue/green-like control.

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

- **Deploy 1 — Expand** — Add the new column (e.g. `full_name`) alongside the old ones. App code dual-writes to both, reads from old columns. v1 still works — it ignores the new column. Safe to roll back: redeploy v1, the new column sits there unused.

- **Deploy 2 — Migrate** — Backfill `full_name` for all existing rows. Switch app code to read from the new column. Continue dual-writing. If this fails, old columns still have valid data — safe to roll back.

- **Deploy 3 — Contract (days or weeks later)** — Stop writing to the old columns, drop them from the schema. This is the point of no return — after this you can't roll back to the old app version.

In your Django experience, you might run `makemigrations` and `migrate` in a single deploy. In production DevOps, the migration and the app deploy are separate events with days between them.

> **Avoid**
>
> - `DROP COLUMN` in the same deploy that stops reading from it
> - `RENAME COLUMN` (old code can't find the column under the new name)
> - `ALTER COLUMN` to a narrower type (e.g. VARCHAR(255) → VARCHAR(50) — longer existing data gets truncated)
> - Adding a NOT NULL constraint without a default (existing rows fail the constraint)

### 2.4 Why Rollback Is Usually a Lie

Everyone says "we can just roll back." Here's why it's almost never that simple:

- **Scenario 1 — Schema has moved forward** — v2 ran a migration adding a NOT NULL column. v1's code doesn't write to it. Rolling back means new rows violate the constraint — writes crash.

- **Scenario 2 — Data format has changed** — v2 started writing addresses in a new JSON structure. v1 expects the old structure and can't parse what v2 wrote while it was live.

- **Scenario 3 — External state has changed** — v2 sent emails, processed payments, published events. You can roll back your code, but you can't un-send emails or un-charge cards.

- **Scenario 4 — Dependent services have moved forward** — v2 of service A started sending a new field that service B now depends on. Rolling back service A breaks service B.

#### What real rollback requires

- A reverse migration script that safely undoes schema changes
- A data migration that converts v2-written data back to v1's format
- Identification of every external side effect and a remediation plan for each
- Testing the rollback path before you need it (which almost nobody does)

> **Honest framing**
>
> Rollback is a forward fix that happens to use the previous version's code. Treat it as a deployment, not an undo button. Plan for it explicitly, test it, and document what it won't fix.

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

> **Why it's dangerous**
>
> Builds are not perfectly reproducible. A `pip install` might pull a newer patch version. An `apt-get update` might include a security patch that changes behaviour. A timestamp or random seed might differ. You've deployed something to production that's never been tested anywhere, even though the source is identical.

#### What may legitimately differ between environments

| Aspect | Must be same | May differ |
| --- | --- | --- |
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

- **Dev** — Auto-deploys on merge to `main`. Fast integration feedback. Minimal resources, shared database, synthetic data. If it breaks, nobody outside the team notices.

- **Staging** — Deploys on promotion from dev (manual trigger or automated after dev smoke tests pass). Catches configuration and integration bugs that only appear at near-production configuration. Same secrets-path structure and deployment process as prod, similar (smaller) infrastructure, sandboxed external services.

- **Production** — Deploys after manual approval gate from staging. Real users, real data, real money. Full monitoring, PagerDuty alerts, Multi-AZ databases, auto-scaling enabled.

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

> **Advantages**
>
> - Near-zero RTO — if one region fails, the other is already serving traffic; DNS just stops sending traffic there
> - Lower latency for geographically distributed users
> - Full utilization of both regions (no idle infrastructure)

> **Challenges**
>
> - **Data conflicts:** simultaneous updates to the same record in different regions need conflict resolution (last-write-wins, application merge logic, CRDTs)
> - **Cost:** double infrastructure, all the time (not just during deploys)
> - **Complexity:** every service must be region-aware, every write must replicate, every cache synchronized or independently warmed

#### Active-Passive

One region serves all traffic. A second sits on standby with a read replica and the ability to be promoted on failure.

```
Route 53 (failover routing)
├── ap-south-1 — ACTIVE (all traffic, primary read-write DB)
└── eu-west-1 — STANDBY (no traffic, read replica, promoted on failure)
    → one-way async replication
```

> **Advantages**
>
> - Simpler — no data conflict resolution needed
> - Cheaper — standby runs minimal infrastructure (DB replica, maybe a cold ASG)
> - Sufficient for most businesses that can tolerate minutes of downtime

> **Challenges**
>
> - **Failover time:** promoting standby, warming instances, updating DNS takes 15–30 minutes typically
> - **Standby rot:** untested failover may not work when needed — run failover drills quarterly
> - **Data loss:** async replication means the standby is always slightly behind — the gap is your RPO

#### Traffic steering (Route 53 routing policies)

- **Latency-based:** routes to whichever region has the lowest latency. Used in active-active.
- **Failover:** primary/secondary record with a health check; if primary fails, DNS resolves to secondary. Used in active-passive.
- **Geolocation:** routes by country/continent — data residency compliance (EU users → EU region).
- **Weighted:** sends X% to one region, Y% to another — gradual region migration.

#### RTO and RPO

These are business decisions that you implement technically.

- **RTO — Recovery Time Objective** — Maximum acceptable downtime. "We cannot be down more than 30 minutes" → RTO 30 minutes. Drives your DR architecture choice.

- **RPO — Recovery Point Objective** — Maximum acceptable data loss, in time. "We can lose at most 5 minutes of data" → RPO 5 minutes. Drives your replication strategy.

| Target | Architecture | Replication | Cost |
| --- | --- | --- | --- |
| RTO 4hr, RPO 24hr | Backups in another region, restore on failure | Daily backup snapshots | Low |
| RTO 30min, RPO 5min | Active-passive, async replication | Continuous async (seconds of lag) | Moderate |
| RTO ~0, RPO ~0 | Active-active, sync replication | Synchronous (adds write latency) | Very high |

> **The honest business conversation:** "You want zero downtime and zero data loss. That costs 2.5x your current infrastructure budget and adds 40ms latency to every write. Are you sure you don't mean 30 minutes and 5 minutes?" Usually, they do.

## AWS & IAM
*AWS Foundations & IAM Deep Dive*

### 3.1 AWS Global Infrastructure

#### Regions

A region (e.g. `ap-south-1` for Mumbai, `us-east-1` for N. Virginia) is a cluster of data centres in a geographic area. Your data stays in the region you choose unless you explicitly replicate it. Not every region has every service, and pricing varies.

For the ramp plan: `ap-south-1` (Mumbai) is close to Dhaka, has all major services, and is cheaper than US regions. `us-east-1` gets new services first and has the most documentation.

#### Availability Zones

Each region has 2–6 AZs — physically separate buildings with independent power, cooling, and networking, connected by low-latency (<1ms) redundant fiber. If AZ-a loses power, AZ-b and AZ-c keep serving.

> **Critical detail**
>
> AZ naming is randomized per account. Your `ap-south-1a` might be a different physical data centre than another account's `ap-south-1a` — AWS does this to prevent everyone piling into the "first" AZ. Use AZ IDs (`aps1-az1`) for cross-account coordination.

#### Service scope

| Scope | Services | Implication |
| --- | --- | --- |
| **Global** | IAM, Route 53, CloudFront, WAF (global), S3 (namespace) | Created once, works in all regions |
| **Regional** | VPC, S3 (data), Lambda, RDS, ECS, Secrets Manager, ALB | Created per region — a VPC in Mumbai doesn't exist in London |
| **AZ-scoped** | EC2 instances, EBS volumes, Subnets, NAT Gateways | Tied to a specific building — an EBS volume in AZ-a can't attach to an instance in AZ-b |

Why this matters: when an EC2 instance in AZ-a dies and Auto Scaling launches a replacement in AZ-b, the old EBS volume is stranded. Stateful data should go in RDS or S3 (regional services), not local EBS.

### 3.2 Shared Responsibility Model

| Layer | Your responsibility | AWS's responsibility |
| --- | --- | --- |
| Application code | ✓ |  |
| IAM policies | ✓ |  |
| Security group / firewall rules | ✓ |  |
| Encryption settings | ✓ |  |
| OS patching (EC2) | ✓ |  |
| OS patching (Fargate, Lambda, RDS) |  | ✓ |
| Network configuration (VPC, subnets) | ✓ |  |
| Physical data centre security |  | ✓ |
| Hypervisor / host OS |  | ✓ |
| Network infrastructure between AZs |  | ✓ |

**The spectrum:** more managed service = less your responsibility.

- EC2: you manage everything from the OS up
- ECS Fargate: AWS manages the host OS; you manage the container
- Lambda: AWS manages everything except your function code and IAM
- RDS: AWS patches the engine; you manage access and encryption

If your RDS database gets breached because the password was `admin123`, that's on you. If the underlying hardware fails, that's on AWS.

### 3.3 Service Quotas

Default limits that will bite you during the ramp plan:

| Service | Default limit | Risk |
| --- | --- | --- |
| VPCs per region | 5 | Shared account with teammate, easy to hit |
| Elastic IPs per region | 5 | NAT Gateways each need one |
| EC2 On-Demand vCPU limit | Varies by family | Auto Scaling silently fails if you hit this |
| S3 buckets per account | 100 | Rarely hit during learning |
| IAM roles per account | 1,000 | Not an issue now, critical at enterprise scale |

Check your limits: `aws service-quotas list-service-quotas --service-code ec2`

> **Watch out**
>
> Hitting a quota doesn't always produce a clear error. Auto Scaling may silently fail to launch instances during a traffic spike.

### 3.4 Tagging Strategy

Set a convention on day one:

_tags_
```
Environment  = dev | staging | prod
Project      = ecommerce-platform
Owner        = fahad
CostCenter   = ramp-plan-2026
ManagedBy    = terraform | manual
```

#### Why tags matter

- **Cost tracking:** see exactly how much dev costs vs staging in the billing console
- **IAM scoping:** write policies like "this role can only manage resources tagged `Environment: dev`"
- **Automation:** scripts can find and stop all instances tagged `Environment: dev` every evening to save money
- **Accountability:** "who left this running?" → check the `Owner` tag

### 3.5 Budget Alarm Setup

$60 per engineer. Set alerts at 50% and 80%.

#### Top cost traps during learning

- Forgetting to stop EC2 instances overnight (~$0.10/hr × 12 hours = $1.20/night)
- NAT Gateways running 24/7 ($0.045/hr = ~$32/month each)
- RDS instances left running on weekends
- Forgotten Elastic IPs not attached to a running instance ($0.005/hr each)

**Cost-saving habit:** at the end of each day, check the billing console or run:

```bash
aws ce get-cost-and-usage \
  --time-period Start=2026-08-27,End=2026-08-31 \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --profile sandbox
```

### 3.6 AWS CLI with Named Profiles

```bash
# Configure
aws configure --profile sandbox
# Enter access key, secret key, region (ap-south-1), output format (json)

# Verify identity
aws sts get-caller-identity --profile sandbox
# Shows: Account ID, ARN, User ID — the "whoami" of AWS

# Set a default to avoid typing --profile every time
export AWS_PROFILE=sandbox
```

> **Debugging tip**
>
> `get-caller-identity` is your best debugging friend. Whenever something returns AccessDenied, run it first — it tells you who AWS thinks you are.

#### How long does `export AWS_PROFILE` last?

`export AWS_PROFILE=sandbox` only applies to the **current shell session** — every `aws` command you run afterward in that same terminal uses it automatically, with no `--profile` flag needed. Close the terminal or open a new tab, and it's gone; that new session falls back to the CLI's default profile again.

```bash
# Make it permanent — every new terminal, not just this session
echo 'export AWS_PROFILE=sandbox' >> ~/.zshrc   # zsh
echo 'export AWS_PROFILE=sandbox' >> ~/.bashrc  # bash

# Apply it to the terminal you already have open, without restarting
source ~/.zshrc
```

> **Override**
>
> Setting `AWS_PROFILE` doesn't lock you in — passing `--profile other-name` on any single command still overrides the environment variable for just that one call. Useful when you're mostly working in one account but need a one-off command against another.

### 3.7 IAM — Identity and Access Management

#### Principals: Users, Groups, and Roles

- **IAM User** — A permanent identity with long-lived credentials (access key + secret, or console password). Used for human console login. Prefer roles wherever possible — long-lived credentials can be leaked.

- **IAM Group** — A collection of users. Policies attached to the group are inherited by every member. Never attach policies directly to a user — put the user in a group, attach the policy to the group. Keeps onboarding/offboarding clean.

- **IAM Role** — A temporary identity that anything can assume — an EC2 instance, a Lambda function, an ECS task, a user from another account. No permanent credentials; issues short-lived tokens (typically 1 hour) via `sts:AssumeRole`. The preferred way to grant access to services.

#### Policy documents — reading them line by line

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReadOnlyS3",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-app-bucket",
        "arn:aws:s3:::my-app-bucket/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "ap-south-1"
        }
      }
    }
  ]
}
```

Read it aloud: "Allow getting objects and listing contents, but only in this specific bucket, and only when the request comes from ap-south-1."

#### The five fields

- **Effect:** `Allow` or `Deny`. Deny always wins over Allow.
- **Action:** the specific API call(s). Never use `*` in production.
- **Resource:** which specific thing, by ARN. `*` means all resources — avoid it.
- **Condition:** optional constraints — IP range, MFA required, region, tag values.
- **Principal** (resource-based policies only): who is granted access.

#### Identity-based vs resource-based policies

**Identity-based policies** attach to a user, group, or role — "What can this identity do?" **Resource-based policies** attach to a resource (S3 bucket policy, SQS queue policy) — "Who can access this resource?" They include a `Principal` field. AWS evaluates both together. For cross-account access you typically need both: a resource policy on the target allowing the external account, and an identity policy on the external role allowing the action.

#### Policy evaluation logic

When an API call is made, AWS evaluates in order:

1. **Explicit deny check:** if any policy anywhere says Deny for this action, it's denied. Game over. Always wins.
2. **SCP check** (AWS Organizations): organization-level guardrails. If the SCP doesn't allow it, denied.
3. **Permission boundary check:** the maximum ceiling for this role. Outside the boundary → denied.
4. **Allow check:** is there at least one identity-based or resource-based policy that explicitly Allows? If yes, allowed; if no, implicit deny.

> **90% of debugging**
>
> - Default deny: no Allow → denied
> - Explicit Deny always wins, even over Allow
> - Allow must be explicit for the specific action on the specific resource

#### Trust policies vs permission policies

Every role has two halves. **Trust policy** — "Who can assume this role?"

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ecs-tasks.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

This says: "ECS tasks can assume this role." No human, no Lambda, no EC2 can. The **permission policy** is "What can this role do once assumed?" — the standard document with Actions and Resources. For cross-account, the trust policy says `"Principal": { "AWS": "arn:aws:iam::OTHER_ACCOUNT:role/auditor" }` — the auditor role from the other account can assume this role.

#### Permission boundaries

A policy that sets the maximum a role can ever do, regardless of what other policies are attached:

```
Boundary says:  "At most S3 and CloudWatch"
Identity policy says: "Allow s3:*, ec2:*, cloudwatch:*"
Effective permissions: s3:* and cloudwatch:* only (ec2:* is outside the boundary)
```

Useful when you let developers create their own roles but want to guarantee they can never exceed a defined scope.

#### Instance profiles and IMDSv2

An **instance profile** is the wrapper that attaches a role to an EC2 instance. The instance gets temporary credentials by calling the Instance Metadata Service.

> **IMDSv1 — insecure**
>
> ```
> curl http://169.254.169.254/latest/meta-data/iam/security-credentials/my-role
> # Returns credentials — no authentication required
> # This is how the 2019 Capital One breach happened (SSRF → metadata → credentials)
> ```

> **IMDSv2 — current**
>
> ```
> TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
>   -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
> curl -H "X-aws-ec2-metadata-token: $TOKEN" \
>   http://169.254.169.254/latest/meta-data/iam/security-credentials/my-role
> # Requires PUT (SSRF attacks typically can't do PUT) + token
> ```

Always enforce IMDSv2: `--metadata-options "HttpTokens=required,HttpEndpoint=enabled"`

#### Debugging AccessDenied with CloudTrail

1. Run `aws sts get-caller-identity` — confirm who you are
2. Check CloudTrail event history for the denied API call
3. The event shows: userIdentity, eventName, resources, errorCode, errorMessage
4. Ask four questions: Does my identity policy Allow this exact action on this exact resource? Does the resource policy (if any) allow my principal? Is there an explicit Deny anywhere overriding the Allow? Am I failing a Condition? (wrong region, no MFA, wrong tag, wrong source IP)

### 3.8 The Three IAM Roles for Assignment A1

#### Role 1 — Application Role (ECS Tasks)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadAppAssets",
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::ecommerce-assets-prod/*"
    },
    {
      "Sid": "ReadSecrets",
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:ap-south-1:*:secret:ecommerce/prod/*"
    },
    {
      "Sid": "WriteAppLogs",
      "Effect": "Allow",
      "Action": ["logs:CreateLogStream", "logs:PutLogEvents"],
      "Resource": "arn:aws:logs:ap-south-1:*:log-group:/ecs/ecommerce-prod:*"
    }
  ]
}
```

> **Justification**
>
> The app reads assets from S3, reads database credentials from Secrets Manager, and writes its own logs. It does NOT get PutObject, DeleteObject, any IAM actions, or any EC2/infra actions. If this container is compromised, the attacker can read assets and secrets for this one service — they cannot modify infrastructure, delete data, or escalate privileges.

#### Role 2 — Operator Role (Human Engineers)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ManageCompute",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*", "ec2:StartInstances", "ec2:StopInstances",
        "ecs:UpdateService", "ecs:DescribeServices", "ecs:RegisterTaskDefinition"
      ],
      "Resource": "*",
      "Condition": { "StringEquals": { "aws:RequestedRegion": "ap-south-1" } }
    },
    {
      "Sid": "ManageSecrets",
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue"],
      "Resource": "arn:aws:secretsmanager:ap-south-1:*:secret:ecommerce/*"
    },
    {
      "Sid": "DenyIAMChanges",
      "Effect": "Deny",
      "Action": "iam:*",
      "Resource": "*"
    }
  ]
}
```

> **Justification**
>
> Operators deploy (update ECS services, register task definitions), manage instances, and rotate secrets. The explicit Deny on `iam:*` prevents operators from modifying permissions. The region condition prevents accidental cross-region operations.

#### Role 3 — Read-Only Auditor

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadEverything",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*", "s3:GetObject", "s3:ListBucket",
        "rds:Describe*", "ecs:Describe*", "ecs:List*",
        "logs:GetLogEvents", "logs:DescribeLogGroups",
        "cloudtrail:LookupEvents", "iam:Get*", "iam:List*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenyAllWrites",
      "Effect": "Deny",
      "Action": [
        "ec2:Run*", "ec2:Terminate*", "ec2:Create*", "ec2:Delete*",
        "s3:PutObject", "s3:DeleteObject",
        "iam:Create*", "iam:Delete*", "iam:Put*", "iam:Attach*"
      ],
      "Resource": "*"
    }
  ]
}
```

> **Justification**
>
> Auditors see everything (logs, configs, IAM, CloudTrail) to verify compliance. Explicit Deny on all mutations ensures that even if someone attaches an additional policy, the role still can't modify anything.

### 3.9 ARNs — Amazon Resource Names

An ARN is the unique address of any resource in all of AWS — like a postal address for your house, but for AWS resources.

Every ARN follows the same pattern:

```
arn:aws:s3:::my-app-bucket
 │   │   │ │ │  └── Resource name (the bucket itself)
 │   │   │ │ └── Account ID (empty for S3 — buckets are globally unique)
 │   │   │ └── Region (empty for S3 — it's a global namespace)
 │   │   └── Service (s3)
 │   └── Partition (aws = standard, aws-cn = China, aws-us-gov = GovCloud)
 └── Prefix (always "arn")
```

The full format is:

_format_
```
arn:aws:service:region:account-id:resource
```

#### Real examples from your account

| Resource | ARN |
| --- | --- |
| Your S3 bucket | `arn:aws:s3:::my-app-bucket` |
| An object inside it | `arn:aws:s3:::my-app-bucket/images/logo.png` |
| Your EC2 instance | `arn:aws:ec2:ap-south-1:111122223333:instance/i-0123456789abcdef0` |
| An IAM role | `arn:aws:iam::111122223333:role/my-app-role` |
| An RDS database | `arn:aws:rds:ap-south-1:111122223333:db:my-database` |

Some fields are empty for global services:

- **S3** — No region, no account ID — bucket names are globally unique across all of AWS, so nobody else can have the same bucket name as you.

- **IAM** — No region — IAM is global, your roles work in every region.

- **EC2, RDS** — All fields filled — they exist in a specific region, in a specific account.

#### Why ARNs matter for you

Remember the IAM policies from 3.7? The `Resource` field uses ARNs to say exactly _which_ thing the policy applies to:

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-app-bucket/*"
}
```

This says "allow reading objects, but **only** from this specific bucket." The `/*` at the end means "all objects inside it." Without the ARN, AWS wouldn't know which bucket you're talking about — there could be millions of S3 buckets across all AWS accounts.

#### Finding a resource's ARN

Usually shown at the top of its detail page in the console, or via CLI:

```bash
# Your EC2 instance's ARN
aws ec2 describe-instances \
  --instance-ids i-0123456789abcdef0 \
  --query "Reservations[].Instances[].{ARN:InstanceId}" \
  --output text
```

### 3.10 Condition Keys in Practice — Restricting by Location

Say the goal is "only allow access from Bangladesh." You'd use the `aws:SourceIp` condition with Bangladesh's public IP ranges:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowOnlyFromBangladesh",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "NotIpAddress": {
          "aws:SourceIp": [
            "103.0.0.0/8",
            "114.128.0.0/10",
            "202.4.96.0/19",
            "103.48.16.0/20"
          ]
        }
      }
    }
  ]
}
```

Read it aloud: _"Deny everything if the request is NOT coming from these IP ranges."_

> **Why Deny + NotIpAddress**
>
> Explicit Deny always wins. An Allow-based rule could be bypassed by attaching another policy that allows access from anywhere. A Deny-based rule can't be overridden — it blocks non-BD traffic no matter what other policies exist.

> **Country-level filtering**
>
> Bangladesh doesn't have one clean CIDR block. IP ranges are scattered across many blocks assigned to ISPs like Grameenphone, Banglalink, Robi, etc. The example above is simplified — a real implementation would need dozens of CIDR ranges that change over time.

#### A better approach for "only from Bangladesh"

Instead of tracking IP ranges, AWS has cleaner options.

**Option 1 — VPN, the production answer.** All access goes through a VPN; no public IP filtering needed. If you're on the VPN, you're authorized — if not, you can't reach anything:

```
Your laptop (Dhaka) → VPN → AWS VPC (private network)
```

**Option 2 — restrict to specific known IPs**, more practical than "all of Bangladesh": your office network and home ISP, two known, stable IPs instead of an entire country's worth of ranges.

```json
{
  "Condition": {
    "IpAddress": {
      "aws:SourceIp": [
        "103.123.45.0/24",
        "114.56.78.0/24"
      ]
    }
  }
}
```

**Option 3 — region restriction**, if the real goal is "keep my resources in the nearest region" rather than "control who connects":

```json
{
  "Condition": {
    "StringEquals": {
      "aws:RequestedRegion": "ap-south-1"
    }
  }
}
```

This prevents anyone — even you — from accidentally creating resources in `us-east-1` or `eu-west-1`. It doesn't restrict who can access; it restricts _where_ resources can exist.

#### Other useful conditions you'll use in the ramp plan

| Condition | What it does | Example use |
| --- | --- | --- |
| `aws:SourceIp` | Restrict by IP address | Office network only |
| `aws:RequestedRegion` | Restrict by region | Only ap-south-1 |
| `aws:MultiFactorAuthPresent` | Require MFA | Sensitive operations need 2FA |
| `aws:PrincipalTag` | Check user's tags | Only team=devops can access |
| `ec2:ResourceTag` | Check resource's tags | Can only manage resources tagged Environment=dev |
| `aws:CurrentTime` | Restrict by time | No deploys outside business hours |

> **Worth noting:** a policy that says "operators can deploy only between 10am and 6pm Bangladesh time," using `aws:CurrentTime`, is a real pattern for reducing late-night risky changes.

### 3.11 IAM Actions Reference

Every distinct `Action` string used across the three IAM roles in 3.8, grouped by service — what each one does, and whether it shows up as an Allow or an explicit Deny.

| Service | Action | What it does | Effect | Used in |
| --- | --- | --- | --- | --- |
| S3 | `s3:GetObject` | Read an object | Allow | 3.7, Role 1 |
| S3 | `s3:ListBucket` | List a bucket's contents | Allow | 3.7, Role 3 |
| S3 | `s3:PutObject` | Write an object | Deny | Role 3 |
| S3 | `s3:DeleteObject` | Delete an object | Deny | Role 3 |
| Secrets Manager | `secretsmanager:GetSecretValue` | Read a secret | Allow | Role 1, Role 2 |
| Secrets Manager | `secretsmanager:PutSecretValue` | Write / rotate a secret | Allow | Role 2 |
| CloudWatch Logs | `logs:CreateLogStream` | Open a new log stream | Allow | Role 1 |
| CloudWatch Logs | `logs:PutLogEvents` | Write log lines | Allow | Role 1 |
| CloudWatch Logs | `logs:GetLogEvents` | Read log lines | Allow | Role 3 |
| CloudWatch Logs | `logs:DescribeLogGroups` | List log groups | Allow | Role 3 |
| EC2 | `ec2:Describe*` | Any read-only Describe call | Allow | Role 2, Role 3 |
| EC2 | `ec2:StartInstances` | Start a stopped instance | Allow | Role 2 |
| EC2 | `ec2:StopInstances` | Stop a running instance | Allow | Role 2 |
| EC2 | `ec2:Run*` | Launch new instances (RunInstances) | Deny | Role 3 |
| EC2 | `ec2:Terminate*` | Terminate instances | Deny | Role 3 |
| EC2 | `ec2:Create*` | Create EC2 resources (volumes, snapshots, etc.) | Deny | Role 3 |
| EC2 | `ec2:Delete*` | Delete EC2 resources | Deny | Role 3 |
| ECS | `ecs:Describe*` | Any read-only Describe call | Allow | Role 3 |
| ECS | `ecs:List*` | Any read-only List call | Allow | Role 3 |
| ECS | `ecs:DescribeServices` | Read service status | Allow | Role 2 |
| ECS | `ecs:UpdateService` | Roll out a new task definition to a service | Allow | Role 2 |
| ECS | `ecs:RegisterTaskDefinition` | Register a new task definition revision | Allow | Role 2 |
| IAM | `iam:*` | Every IAM action, no exceptions | Deny | Role 2 |
| IAM | `iam:Get*` | Read a single IAM resource | Allow | Role 3 |
| IAM | `iam:List*` | List IAM resources | Allow | Role 3 |
| IAM | `iam:Create*` | Create IAM resources (users, roles, policies) | Deny | Role 3 |
| IAM | `iam:Delete*` | Delete IAM resources | Deny | Role 3 |
| IAM | `iam:Put*` | Write inline policies / config | Deny | Role 3 |
| IAM | `iam:Attach*` | Attach a managed policy to a principal | Deny | Role 3 |
| RDS | `rds:Describe*` | Any read-only Describe call | Allow | Role 3 |
| CloudTrail | `cloudtrail:LookupEvents` | Search the audit log | Allow | Role 3 |
| STS | `sts:AssumeRole` | Assume a role and get temporary credentials | Allow | 3.7, Trust policies |

> **Reading tip**
>
> A trailing `*` is a wildcard within that action namespace — `ec2:Describe*` covers `DescribeInstances`, `DescribeVolumes`, every Describe call EC2 has, present or future. `iam:*` is the widest wildcard here: every action in the entire IAM service.

## VPC, Built by Hand
*Networking & the VPC Build Exercise*

### 4.1 What a VPC Is

A VPC (Virtual Private Cloud) is your own isolated network within an AWS region — think of it as your private data centre network in the cloud. Nothing can enter or leave your VPC unless you explicitly allow it.

When you create a VPC, you define a CIDR block — the total pool of private IP addresses available to everything inside it.

### 4.2 CIDR Planning on Paper

CIDR (Classless Inter-Domain Routing) notation defines a range of IP addresses. Before the mental math, here's what's actually happening under the hood.

#### An IP address is just 32 bits (ones and zeros)

You see `10.0.0.0`, but the computer sees:

```
10  .  0   .  0   .  0
↓      ↓      ↓      ↓
00001010.00000000.00000000.00000000
```

Each of the 4 numbers (called octets) is 8 bits. 4 × 8 = **32 bits total**. The range of each octet is 0–255 because 8 bits can represent 2⁸ = 256 values (`00000000` to `11111111`).

#### The `/` number = how many bits are locked

The number after `/` tells you: **how many bits from the left are fixed (the network part).** The remaining bits are yours to use for individual addresses (the host part).

**The / number = how many bits are LOCKED from the left**

| CIDR | Locked bits (network) | Free bits (host) | Total addresses |
| --- | --- | --- | --- |
| `/16` | `00001010.00000000` — 16 bits (10.0) | `xxxxxxxx.xxxxxxxx` — 16 bits | 2¹⁶ = 65,536 |
| `/24` | `00001010.00000000.00000000` — 24 bits (10.0.0) | `xxxxxxxx` — 8 bits | 2⁸ = 256 |
| `/28` | `00001010.00000000.00000000.0000` — 28 bits (10.0.0.0–15) | `xxxx` — 4 bits | 2⁴ = 16 |

- Locked = network part (same for every address in this range)
- Free = host part (each combination is one unique address)

**Formula:** Total addresses = 2 ^ (32 − the / number)

**Quick shortcut:** bigger `/` number = fewer addresses (more bits locked) · smaller `/` number = more addresses

#### How the calculation works

Each free bit can be either 0 or 1 — two choices. With multiple free bits, you multiply the choices together:

```
/16 → 32 − 16 = 16 free bits

2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2
└──────────────────────── 16 times ────────────────────────────────┘
= 2¹⁶ = 65,536 addresses
```

```
/24 → 32 − 24 = 8 free bits

2 × 2 × 2 × 2 × 2 × 2 × 2 × 2
└────────── 8 times ───────────┘
= 2⁸ = 256 addresses
```

```
/28 → 32 − 28 = 4 free bits

2 × 2 × 2 × 2
└─ 4 times ──┘
= 2⁴ = 16 addresses
```

Think of it like a combination lock. A 4-digit lock where each digit is 0–9 has 10 × 10 × 10 × 10 = 10,000 combinations. Same idea here — but each "digit" is a bit (only 0 or 1), so it's 2 instead of 10, multiplied by itself for each free bit.

#### Walking through /24 step by step

`10.0.1.0/24` means:

```
10   .   0   .   1   .   0
Fixed    Fixed   Fixed   Free (this octet can be anything 0-255)
```

24 bits are locked = the first 3 octets (`10.0.1`) never change. The last octet (8 bits) is free, so it ranges from 0 to 255:

```
First address:  10.0.1.0
                10.0.1.1
                10.0.1.2
                ...
                10.0.1.254
Last address:   10.0.1.255

Total: 256 addresses
```

#### Now /16

`10.0.0.0/16` means:

```
10   .   0   .   0   .   0
Fixed    Fixed   Free     Free (last 2 octets can be anything)
```

16 bits locked = first 2 octets (`10.0`) never change. The last 2 octets are free:

```
First address:  10.0.0.0
                10.0.0.1
                ...
                10.0.0.255
                10.0.1.0      ← third octet increments
                10.0.1.1
                ...
                10.0.255.254
Last address:   10.0.255.255

Total: 256 × 256 = 65,536 addresses
```

#### And /28

`10.0.0.0/28` means 28 bits are locked — that's 3 full octets (24 bits) plus 4 more bits into the last octet. Only 4 bits are free:

```
Last octet in binary: 0000xxxx
                           ↑ only these 4 bits change

xxxx can be: 0000 (0) to 1111 (15)

First address:  10.0.0.0
Last address:   10.0.0.15

Total: 2⁴ = 16 addresses
```

#### The cheat sheet you'll actually use

Every CIDR from /16 to /32. The "third octet range" column is for mid-octet splits — the tricky ones. Pin this somewhere visible.

| CIDR | Free bits | Total addresses | Usable (AWS) | 3rd octet: free bits | 3rd octet range | Used for |
| --- | --- | --- | --- | --- | --- | --- |
| `/16` | 16 | 65,536 | 65,531 | 8 (fully free) | 0 – 255 | VPC level |
| `/17` | 15 | 32,768 | 32,763 | 7 | 0 – 127 | Half a VPC |
| `/18` | 14 | 16,384 | 16,379 | 6 | 0 – 63 | Large subnet |
| `/19` | 13 | 8,192 | 8,187 | 5 | 0 – 31 | Large subnet |
| `/20` | 12 | 4,096 | 4,091 | 4 | 0 – 15 | Large subnet |
| `/21` | 11 | 2,048 | 2,043 | 3 | 0 – 7 | Medium subnet |
| `/22` | 10 | 1,024 | 1,019 | 2 | 0 – 3 | Medium subnet |
| `/23` | 9 | 512 | 507 | 1 | 0 – 1 | Medium subnet |
| `/24` | 8 | 256 | 251 | 0 (locked) | — | Standard subnet (most common) |
| `/25` | 7 | 128 | 123 | 4th octet split: 0 – 127 | Small subnet |  |
| `/26` | 6 | 64 | 59 | 4th octet split: 0 – 63 | Small subnet |  |
| `/27` | 5 | 32 | 27 | 4th octet split: 0 – 31 | Small subnet |  |
| `/28` | 4 | 16 | 11 | 4th octet split: 0 – 15 | AWS minimum subnet |  |
| `/29` | 3 | 8 | 3 | 4th octet split: 0 – 7 | Tiny (only 3 usable!) |  |
| `/30` | 2 | 4 | — | 4th octet split: 0 – 3 | Point-to-point link |  |
| `/31` | 1 | 2 | — | 4th octet split: 0 – 1 | Point-to-point link (RFC 3021) |  |
| `/32` | 0 | 1 | — | Single IP | Security group rules, host routes |  |

> **Pattern**
>
> Each step down in the CIDR number **doubles** the addresses. /24 = 256, /23 = 512, /22 = 1,024. Each step up **halves** them. /24 = 256, /25 = 128, /26 = 64.

> **Mid-octet formula**
>
> For /17 to /23 (third octet splits): spill = /number − 16. Free bits in 3rd octet = 8 − spill. Max value = 2^free − 1. For /25 to /31 (fourth octet splits): same idea but spill = /number − 24.

#### AWS reserves 5 IPs in every subnet

- .0 — network address
- .1 — VPC router
- .2 — DNS server
- .3 — reserved for future use
- .255 — broadcast (not supported in VPC, but reserved)

So a /24 subnet (256 addresses) actually has 251 usable.

#### How this applies to your VPC on Day 4

```
VPC:         10.0.0.0/16      ← your entire network: 65,536 addresses
             │
             ├── 10.0.1.0/24  ← public subnet AZ-a: 256 addresses (251 usable)
             ├── 10.0.2.0/24  ← public subnet AZ-b: 256 addresses
             ├── 10.0.10.0/24 ← private app AZ-a:   256 addresses
             ├── 10.0.11.0/24 ← private app AZ-b:   256 addresses
             ├── 10.0.20.0/24 ← private DB AZ-a:    256 addresses
             └── 10.0.21.0/24 ← private DB AZ-b:    256 addresses

             6 subnets × 256 = 1,536 used out of 65,536 available
             Plenty of room to add more subnets later
```

The VPC is /16 (big pool), and you carve it into /24 subnets (smaller pools) — like dividing a large office floor into rooms: the floor is the VPC, each room is a subnet.

#### Why this layout

- Gaps between ranges (1–2, 10–11, 20–21) leave room for future subnets
- Two AZs for fault tolerance (if AZ-a dies, AZ-b keeps running)
- Three tiers (public, app, database) for network-level isolation
- The 10.0.x.0 numbering makes it easy to identify the tier at a glance

#### Practice — CIDR & Subnetting Quiz

**Q1.** How many total IP addresses are in 10.0.0.0/24?

- **A)** 128
- **B)** 256
- **C)** 512
- **D)** 1,024

<details>
<summary>Show answer</summary>

**✓ Correct — B) 256**

32 − 24 = 8 free bits. 2⁸ = 256 addresses.

- **A) 128** — This would be 2⁷, which is a /25 (32 − 7 = 25), not /24.
- **B) 256** — ✓ Correct. 32 − 24 = 8 free bits → 2⁸ = 256.
- **C) 512** — This would be 2⁹, which is a /23 (32 − 9 = 23).
- **D) 1,024** — This would be 2¹⁰, which is a /22.

</details>

**Q2.** How many **usable** IP addresses in a /24 subnet on AWS?

- **A)** 256
- **B)** 254
- **C)** 251
- **D)** 250

<details>
<summary>Show answer</summary>

**✓ Correct — C) 251**

256 total − 5 reserved by AWS = 251 usable.

- **A) 256** — This is the _total_ count, not usable. AWS reserves 5 IPs in every subnet.
- **B) 254** — This would be correct in traditional networking (just .0 and .255 reserved). But AWS reserves 5: .0 (network), .1 (router), .2 (DNS), .3 (future), .255 (broadcast).
- **C) 251** — ✓ Correct. 256 − 5 = 251 usable.
- **D) 250** — Off by one. Only 5 are reserved, not 6.

</details>

**Q3.** What is the IP range of 10.0.5.0/24?

- **A)** 10.0.5.0 – 10.0.5.255
- **B)** 10.0.0.0 – 10.0.5.255
- **C)** 10.0.5.0 – 10.0.6.0
- **D)** 10.0.5.0 – 10.0.5.128

<details>
<summary>Show answer</summary>

**✓ Correct — A) 10.0.5.0 – 10.0.5.255**

/24 locks the first 3 octets (10.0.5). Only the last octet is free (0–255).

- **A) 10.0.5.0 – 10.0.5.255** — ✓ Correct. /24 = first 3 octets locked, last octet free (0–255).
- **B) 10.0.0.0 – 10.0.5.255** — Wrong. This starts at 10.0.0.0, but the CIDR starts at 10.0.5.0. The third octet is locked at 5, not ranging 0–5.
- **C) 10.0.5.0 – 10.0.6.0** — Wrong. This crosses into the next subnet (10.0.6.x). A /24 stays within one value of the third octet.
- **D) 10.0.5.0 – 10.0.5.128** — Wrong. This is only half the range. A /24 goes up to .255, not .128. A range ending at .128 would be closer to a /25.

</details>

**Q4.** How many addresses in a /20 subnet?

- **A)** 1,024
- **B)** 2,048
- **C)** 4,096
- **D)** 8,192

<details>
<summary>Show answer</summary>

**✓ Correct — C) 4,096**

32 − 20 = 12 free bits. 2¹² = 4,096.

- **A) 1,024** — This is 2¹⁰ = /22 (32 − 10 = 22).
- **B) 2,048** — This is 2¹¹ = /21 (32 − 11 = 21).
- **C) 4,096** — ✓ Correct. 2¹² = /20.
- **D) 8,192** — This is 2¹³ = /19 (32 − 13 = 19).

</details>

**Q5.** Which CIDR gives you exactly 16 addresses?

- **A)** /26
- **B)** /27
- **C)** /28
- **D)** /30

<details>
<summary>Show answer</summary>

**✓ Correct — C) /28**

16 = 2⁴. You need 4 free bits. 32 − 4 = 28.

- **A) /26** — 32 − 26 = 6 free bits → 2⁶ = 64 addresses. Too many.
- **B) /27** — 32 − 27 = 5 free bits → 2⁵ = 32 addresses. Still too many.
- **C) /28** — ✓ Correct. 32 − 28 = 4 free bits → 2⁴ = 16.
- **D) /30** — 32 − 30 = 2 free bits → 2² = 4 addresses. Too few.

</details>

**Q6.** You have 10.0.0.0/16 as your VPC. Can 10.0.3.0/24 be a subnet inside it?

- **A)** Yes — 10.0.3.0 falls within the 10.0.0.0/16 range
- **B)** No — /24 is larger than /16
- **C)** No — the third octet must be 0
- **D)** Yes — but only if it's in the same AZ

<details>
<summary>Show answer</summary>

**✓ Correct — A) Yes**

This is purely a math question: does the subnet's range fit inside the VPC's range?

- **A) Yes — falls within range** — ✓ Correct. VPC range is 10.0.0.0–10.0.255.255. Subnet range is 10.0.3.0–10.0.3.255. It fits.
- **B) No — /24 is larger than /16** — Backwards. Larger / number = smaller subnet. /24 (256 IPs) is smaller than /16 (65,536 IPs), so it fits inside.
- **C) No — third octet must be 0** — Wrong. The /16 VPC covers ALL values of the third octet (0–255). 10.0.3.x, 10.0.99.x, 10.0.200.x all fit.
- **D) Yes — but only if same AZ** — The AZ part is wrong. CIDR validity is pure math — the IPs either fit or they don't, regardless of which AZ you place the subnet in. You choose the AZ after the CIDR is validated.

</details>

**Q7.** Can these two subnets coexist in the same VPC? `10.0.1.0/24` and `10.0.1.128/25`

- **A)** Yes — they're different CIDR blocks
- **B)** No — they overlap (10.0.1.128–255 is in both)
- **C)** Yes — /25 is smaller so it fits inside /24
- **D)** No — you can't use /25 in AWS

<details>
<summary>Show answer</summary>

**✓ Correct — B) No, they overlap**

Write out both ranges — the overlap becomes obvious.

- **A) Yes — different CIDRs** — Different CIDR notation doesn't mean non-overlapping. 10.0.1.0/24 covers .0–.255; 10.0.1.128/25 covers .128–.255. The .128–.255 range exists in both — that's an overlap. AWS rejects this.
- **B) No — they overlap** — ✓ Correct. /24 = 10.0.1.0–10.0.1.255. /25 = 10.0.1.128–10.0.1.255. The second range is entirely inside the first.
- **C) Yes — /25 fits inside /24** — "Fits inside" is exactly the problem! Two subnets cannot overlap — each IP address must belong to exactly one subnet. The /25 is a subset of the /24, so they conflict.
- **D) No — can't use /25** — You can use /25 in AWS. The minimum is /28. The problem is the overlap, not the prefix length.

</details>

**Q8.** You need a subnet for 100 EC2 instances on AWS. What's the smallest CIDR that fits?

- **A)** /25 (128 addresses, 123 usable)
- **B)** /24 (256 addresses, 251 usable)
- **C)** /26 (64 addresses, 59 usable)
- **D)** /27 (32 addresses, 27 usable)

<details>
<summary>Show answer</summary>

**✓ Correct — A) /25**

You need 100 instances + 5 AWS reserved = 105 minimum. Find the smallest power of 2 that's ≥ 105.

- **A) /25 — 128 total, 123 usable** — ✓ Correct. 123 usable ≥ 100 needed. This is the smallest CIDR that works.
- **B) /24 — 256 total, 251 usable** — Works, but wastes 151 addresses. /25 is sufficient and more efficient.
- **C) /26 — 64 total, 59 usable** — Too small. 59 usable < 100 needed. You'd run out of IPs.
- **D) /27 — 32 total, 27 usable** — Way too small. Only 27 usable IPs for 100 instances.

</details>

**Q9.** What is the IP range of 172.16.0.0/20?

- **A)** 172.16.0.0 – 172.16.0.255
- **B)** 172.16.0.0 – 172.16.15.255
- **C)** 172.16.0.0 – 172.16.31.255
- **D)** 172.16.0.0 – 172.16.255.255

<details>
<summary>Show answer</summary>

**✓ Correct — B) 172.16.0.0 – 172.16.15.255**

/20 locks 20 bits. The first 2 octets use 16 bits, leaving 4 more locked bits in the third octet. The third octet is _split_: upper 4 bits locked, lower 4 bits free.

- **A) 172.16.0.0 – 172.16.0.255** — This is a /24 (only 256 addresses). /20 is much larger — 4,096 addresses. The third octet isn't locked at 0; it can range 0–15.
- **B) 172.16.0.0 – 172.16.15.255** — ✓ Correct. 4 free bits in the third octet → 2⁴ − 1 = 15 → range 0–15. Fourth octet fully free (0–255). Total: 16 × 256 = 4,096.
- **C) 172.16.0.0 – 172.16.31.255** — This would be /19. In /19: 32 − 19 = 13 free bits. Third octet has 5 free bits → 2⁵ − 1 = 31. Close, but one bit off from /20.
- **D) 172.16.0.0 – 172.16.255.255** — This is a /16 (entire third and fourth octets free). /20 locks 4 bits of the third octet, so it can only go up to 15, not 255.

</details>

**Q10.** Your VPC is 10.0.0.0/16. How many /24 subnets can it hold?

- **A)** 16
- **B)** 64
- **C)** 256
- **D)** 512

<details>
<summary>Show answer</summary>

**✓ Correct — C) 256**

Divide the VPC's total by the subnet's size: 65,536 ÷ 256 = 256.

- **A) 16** — This would be correct if each subnet were /20 (4,096 addresses). 65,536 ÷ 4,096 = 16.
- **B) 64** — This would be /24-sized subnets in a /18 VPC. 16,384 ÷ 256 = 64.
- **C) 256** — ✓ Correct. /16 = 65,536 addresses. /24 = 256 addresses. 65,536 ÷ 256 = 256. The third octet (0–255) gives exactly 256 possible /24 blocks.
- **D) 512** — This would be /25-sized subnets (128 each) in a /16 VPC. 65,536 ÷ 128 = 512.

</details>

#### Deep Practice — CIDR — Building from Basics to Mid-Octet Splits

**Q1.** How many total bits are in an IPv4 address?

- **A)** 16 bits
- **B)** 32 bits
- **C)** 64 bits
- **D)** 128 bits

<details>
<summary>Show answer</summary>

**✓ Correct — B) 32 bits**

An IP address is 4 octets × 8 bits = 32 bits. This never changes for IPv4.

- **A) 16 bits** — This is only 2 octets. An IPv4 address has 4 octets.
- **B) 32 bits** — ✓ Correct. 4 octets × 8 bits = 32.
- **C) 64 bits** — This would be 8 octets. IPv4 only has 4.
- **D) 128 bits** — This is the size of an IPv6 address, not IPv4.

</details>

**Q2.** In 10.0.0.0/24, what does the /24 mean?

- **A)** The number of servers allowed
- **B)** The total number of addresses
- **C)** How many bits are locked from the left (the network part)
- **D)** The cost tier of the subnet

<details>
<summary>Show answer</summary>

**✓ Correct — C) Bits locked from the left**

The / number tells you how many of the 32 bits are fixed (the network part). The remaining bits are free for host addresses.

- **A) Number of servers** — No, the / has nothing to do with server count directly. It defines the address range size.
- **B) Total addresses** — Close idea, but the / number isn't the count itself. It's the locked bits. You calculate addresses from it: 2^(32 − /number).
- **C) Bits locked from the left** — ✓ Correct. /24 = 24 bits locked, 8 bits free.
- **D) Cost tier** — No, CIDR has nothing to do with pricing.

</details>

**Q3.** If 24 bits are locked, how many bits are FREE?

- **A)** 8
- **B)** 24
- **C)** 16
- **D)** 4

<details>
<summary>Show answer</summary>

**✓ Correct — A) 8**

32 total − 24 locked = 8 free bits. This subtraction is the first step of every CIDR calculation.

- **A) 8** — ✓ Correct. 32 − 24 = 8.
- **B) 24** — That's the locked bits, not the free bits. You subtracted the wrong way.
- **C) 16** — This would be 32 − 16, which is a /16, not /24.
- **D) 4** — This would be 32 − 28, which is a /28.

</details>

**Q4.** If you have 3 free bits, how many addresses? (2 × 2 × 2 = ?)

- **A)** 6
- **B)** 8
- **C)** 9
- **D)** 12

<details>
<summary>Show answer</summary>

**✓ Correct — B) 8**

Each bit has 2 choices (0 or 1). You multiply: 2 × 2 × 2 = 8.

- **A) 6** — You might have added: 2 + 2 + 2 = 6. But bits multiply, not add.
- **B) 8** — ✓ Correct. 2 × 2 × 2 = 2³ = 8.
- **C) 9** — You might be thinking 3² = 9. But it's 2³, not 3².
- **D) 12** — No standard operation on 2 and 3 gives 12 here.

</details>

**Q5.** How many addresses in a /26? (Two steps: free bits, then 2^free)

- **A)** 26
- **B)** 32
- **C)** 64
- **D)** 128

<details>
<summary>Show answer</summary>

**✓ Correct — C) 64**

Step 1: 32 − 26 = 6 free bits. Step 2: 2⁶ = 64.

- **A) 26** — That's the / number itself, not the address count. Don't confuse the two.
- **B) 32** — This is 2⁵ = /27. One bit off.
- **C) 64** — ✓ Correct. 2⁶ = 2×2×2×2×2×2 = 64.
- **D) 128** — This is 2⁷ = /25. You subtracted one too many.

</details>

**Q6.** How many addresses in a /25?

- **A)** 128
- **B)** 64
- **C)** 256
- **D)** 32

<details>
<summary>Show answer</summary>

**✓ Correct — A) 128**

32 − 25 = 7 free bits. 2⁷ = 128.

- **A) 128** — ✓ Correct. 2⁷ = 128.
- **B) 64** — This is 2⁶ = /26. One bit too few.
- **C) 256** — This is 2⁸ = /24. One bit too many.
- **D) 32** — This is 2⁵ = /27. Two bits too few.

</details>

**Q7.** Which is SMALLER: /24 or /28?

- **A)** /28 is bigger — it has more addresses
- **B)** /28 is smaller — it has fewer addresses (16 vs 256)
- **C)** They're the same size
- **D)** It depends on the region

<details>
<summary>Show answer</summary>

**✓ Correct — B) /28 is smaller**

Bigger / number = more locked bits = fewer free bits = fewer addresses = smaller subnet.

- **A) /28 is bigger** — This is the most common CIDR mistake. The / number and the size go in opposite directions. /28 locks more bits, so fewer addresses.
- **B) /28 is smaller** — ✓ Correct. /28 = 2⁴ = 16 addresses. /24 = 2⁸ = 256 addresses.
- **C) Same size** — No, different / numbers always give different sizes.
- **D) Depends on region** — CIDR is pure math. Region doesn't affect it.

</details>

**Q8.** What is the range of 10.0.5.0/24?

- **A)** 10.0.5.0 – 10.0.5.255
- **B)** 10.0.0.0 – 10.0.5.255
- **C)** 10.0.5.0 – 10.0.255.255
- **D)** 10.5.0.0 – 10.5.255.255

<details>
<summary>Show answer</summary>

**✓ Correct — A) 10.0.5.0 – 10.0.5.255**

/24 locks 3 octets. The third octet is 5 and stays 5. Only the last octet is free: 0–255.

- **A) 10.0.5.0 – 10.0.5.255** — ✓ Correct. Three octets locked (10.0.5), last octet free (0–255).
- **B) 10.0.0.0 – 10.0.5.255** — Wrong start address. The CIDR starts at 10.0.5.0, not 10.0.0.0. The third octet is locked at 5.
- **C) 10.0.5.0 – 10.0.255.255** — This frees the third octet (5–255). That would be a /16 starting at 10.0.5.0, not a /24.
- **D) 10.5.0.0 – 10.5.255.255** — The 5 moved to the second octet. The original has 5 in the third octet position.

</details>

**Q9.** What is the range of 10.0.0.0/16?

- **A)** 10.0.0.0 – 10.0.0.255
- **B)** 10.0.0.0 – 10.0.16.255
- **C)** 10.0.0.0 – 10.0.255.255
- **D)** 10.0.0.0 – 10.255.255.255

<details>
<summary>Show answer</summary>

**✓ Correct — C) 10.0.0.0 – 10.0.255.255**

/16 locks 2 octets (10.0). The third AND fourth octets are both free (each 0–255).

- **A) 10.0.0.0 – 10.0.0.255** — This is a /24 (only last octet free). /16 frees two octets.
- **B) 10.0.0.0 – 10.0.16.255** — The "16" doesn't go into the IP range. /16 means 16 bits locked, which frees the entire third and fourth octets.
- **C) 10.0.0.0 – 10.0.255.255** — ✓ Correct. Two octets locked (10.0), two free (0–255 each).
- **D) 10.0.0.0 – 10.255.255.255** — This frees three octets, which would be a /8, not /16.

</details>

**Q10.** /16 locks 16 bits. How many **full octets** is that?

- **A)** 1 full octet (the first)
- **B)** 2 full octets (the first two)
- **C)** 3 full octets
- **D)** 16 octets

<details>
<summary>Show answer</summary>

**✓ Correct — B) 2 full octets**

16 bits ÷ 8 bits per octet = exactly 2 octets. This is a clean octet boundary — no splitting.

- **A) 1 octet** — 1 octet = 8 bits. That's a /8, not /16.
- **B) 2 octets** — ✓ Correct. 16 ÷ 8 = 2. Clean boundary.
- **C) 3 octets** — 3 octets = 24 bits. That's a /24.
- **D) 16 octets** — Octets and bits are different. 16 bits = 2 octets, not 16 octets.

</details>

**Q11.** /20 locks 20 bits. The first 2 octets use 16 bits. Where do the remaining 4 locked bits go?

- **A)** Exactly 2 full octets, nothing more
- **B)** 2 full octets + 4 bits into the third octet
- **C)** 2 full octets + the entire third octet
- **D)** 20 octets

<details>
<summary>Show answer</summary>

**✓ Correct — B) 2 octets + 4 bits into the third**

20 − 16 = 4 extra bits that spill into the third octet. The third octet is now SPLIT: 4 bits locked, 4 bits free. This is what makes mid-octet CIDRs like /20 tricky.

- **A) Exactly 2 octets** — That would only be 16 bits. We have 20 to lock — 4 more bits need to go somewhere.
- **B) 2 octets + 4 bits into the third** — ✓ Correct. 16 + 4 = 20. The third octet is split in half.
- **C) 2 octets + entire third** — The entire third octet would be 8 more bits = 24 total. That's a /24, not /20.
- **D) 20 octets** — An IPv4 address only has 4 octets total.

</details>

**Q12.** In a /20, the third octet has 4 locked bits and 4 free bits. What values can the third octet be?

- **A)** Only 0 (it's fully locked)
- **B)** 0 – 3 (4 values)
- **C)** 0 – 15 (16 values)
- **D)** 0 – 255 (fully free)

<details>
<summary>Show answer</summary>

**✓ Correct — C) 0 – 15**

4 free bits = 2⁴ = 16 possible values. Range: 0 to 15.

- **A) Only 0** — It's not fully locked — 4 bits are free. Zero free bits would mean a value of only 0.
- **B) 0 – 3** — 4 values = 2² = 2 free bits. But we have 4 free bits, not 2. Don't confuse the number of free bits (4) with the number of values from 2 free bits (4).
- **C) 0 – 15** — ✓ Correct. 4 free bits → 2⁴ = 16 values → 0 through 15.
- **D) 0 – 255** — That would mean all 8 bits are free, which is a /16. In /20, only 4 of the 8 bits in the third octet are free.

</details>

**Q13.** Now put it together: what is the range of 172.16.0.0/20?

- **A)** 172.16.0.0 – 172.16.0.255
- **B)** 172.16.0.0 – 172.16.15.255
- **C)** 172.16.0.0 – 172.16.31.255
- **D)** 172.16.0.0 – 172.16.255.255

<details>
<summary>Show answer</summary>

**✓ Correct — B) 172.16.0.0 – 172.16.15.255**

Combine everything from the previous questions: first 2 octets locked (172.16). Third octet: 0–15 (4 free bits). Fourth octet: 0–255 (fully free).

- **A) 172.16.0.0 – 172.16.0.255** — This is a /24 (256 addresses). It only uses the fourth octet. /20 is much bigger — 4,096 addresses spread across 16 values of the third octet.
- **B) 172.16.0.0 – 172.16.15.255** — ✓ Correct. Third octet: 0–15 (from Q12). Fourth octet: 0–255. Total: 16 × 256 = 4,096.
- **C) 172.16.0.0 – 172.16.31.255** — 31 = 2⁵ − 1 = 5 free bits in third octet. That's /19 (19 locked = 16 + 3), not /20 (16 + 4). One extra free bit.
- **D) 172.16.0.0 – 172.16.255.255** — 255 means the entire third octet is free = /16. The /20 locks 4 bits of the third octet, limiting it to 0–15.

</details>

**Q14.** Same method — what is the range of 192.168.0.0/19?

- **A)** 192.168.0.0 – 192.168.15.255
- **B)** 192.168.0.0 – 192.168.19.255
- **C)** 192.168.0.0 – 192.168.31.255
- **D)** 192.168.0.0 – 192.168.63.255

<details>
<summary>Show answer</summary>

**✓ Correct — C) 192.168.0.0 – 192.168.31.255**

/19: 19 − 16 = 3 bits locked in third octet. 8 − 3 = 5 free bits. 2⁵ = 32 values = 0–31.

- **A) ...15.255** — 15 = 2⁴ − 1 = 4 free bits in third octet. That's /20, not /19.
- **B) ...19.255** — 19 is the / number, not the max of the third octet. Don't put the / number into the range.
- **C) ...31.255** — ✓ Correct. 5 free bits → 2⁵ = 32 → max value = 31.
- **D) ...63.255** — 63 = 2⁶ − 1 = 6 free bits. That's /18 (16 + 2 locked in third), not /19.

</details>

**Q15.** What is the range and size of 10.1.0.0/21?

- **A)** 10.1.0.0 – 10.1.0.255 (256 addresses)
- **B)** 10.1.0.0 – 10.1.3.255 (1,024 addresses)
- **C)** 10.1.0.0 – 10.1.15.255 (4,096 addresses)
- **D)** 10.1.0.0 – 10.1.7.255 (2,048 addresses)

<details>
<summary>Show answer</summary>

**✓ Correct — D) 10.1.0.0 – 10.1.7.255 (2,048)**

/21: 21 − 16 = 5 bits locked in third octet. 8 − 5 = 3 free bits. 2³ = 8 values = 0–7. Fourth octet fully free. Total: 8 × 256 = 2,048.

- **A) ...0.255 (256)** — This is a /24. Only the fourth octet is free. /21 has 3 free bits in the third octet too.
- **B) ...3.255 (1,024)** — 3 = 2² − 1 = 2 free bits in third octet = /22 (16 + 6). Close, but one bit off from /21.
- **C) ...15.255 (4,096)** — 15 = 2⁴ − 1 = 4 free bits = /20. /21 has one fewer free bit.
- **D) ...7.255 (2,048)** — ✓ Correct. 3 free bits → 2³ = 8 → max value 7. Total: 8 × 256 = 2,048.

</details>

### 4.3 Subnet Types: Public vs Private

- **Public subnet** — Has a route to the Internet Gateway. Instances can have public IPs and be reached from the internet (if the security group allows it). Used for load balancers, bastion hosts, NAT gateways.

- **Private subnet** — No direct route to the internet. Instances can't be reached from outside; they access the internet through a NAT Gateway in a public subnet. Used for application servers, databases, anything that shouldn't be directly internet-accessible.

> **Golden rule**
>
> Databases and application servers go in private subnets. Only load balancers and NAT gateways go in public subnets.

### 4.4 Route Tables

Every subnet is associated with a route table that determines where traffic goes.

#### Public subnet route table

```
Destination        Target
10.0.0.0/16        local           ← traffic within the VPC stays in the VPC
0.0.0.0/0          igw-xxxxxxxx    ← everything else goes to the Internet Gateway
```

#### Private subnet route table

```
Destination        Target
10.0.0.0/16        local           ← traffic within the VPC stays in the VPC
0.0.0.0/0          nat-xxxxxxxx    ← everything else goes through NAT Gateway
```

The difference: public subnets route to the Internet Gateway (direct, bidirectional). Private subnets route through a NAT Gateway (outbound only — the internet can't initiate connections in).

### 4.5 Key Network Components

#### Internet Gateway (IGW)

Attached to the VPC. Provides a path between the VPC and the internet — instances in public subnets with a public IP communicate through it. One IGW per VPC; horizontally scaled, redundant, and managed by AWS — not a bottleneck.

#### NAT Gateway

Sits in a public subnet. Lets private-subnet instances initiate outbound connections (downloading updates, calling external APIs) without being reachable from the internet.

> **Cost**
>
> $0.045/hour (~$32/month) per NAT Gateway, plus data processing charges. For production, put one in each AZ for fault tolerance. For dev/learning, one is enough — just know it's a single point of failure.

> **Cost-saving tip**
>
> Consider a NAT Instance (a small EC2 instance configured to do NAT) instead — ~$3/month for a t3.nano vs $32/month. Less reliable, but fine for learning.

#### Bastion Host (Jump Box)

An EC2 instance in a public subnet that you SSH into, then SSH from there into private instances — the only instance with a public IP and SSH access, a single auditable entry point into your private network.

**Modern alternative:** AWS Systems Manager Session Manager — no bastion, no SSH keys to manage, all sessions logged in CloudTrail.

### 4.6 Security Groups vs NACLs

Two layers of firewall, working at different levels.

| Aspect | Security Group | NACL |
| --- | --- | --- |
| **Level** | Instance (attached to ENI) | Subnet (all traffic entering/leaving) |
| **State** | Stateful — allowed inbound response is auto-allowed outbound | Stateless — must explicitly allow both directions |
| **Rules** | Allow only (implicit deny for everything else) | Allow and Deny, evaluated in rule-number order |
| **Default** | Deny all inbound, allow all outbound | Allow all inbound and outbound |
| **Evaluation** | All rules together (most permissive wins) | In order (first match wins) |

#### Practical security group design

> **ALB (public)**
>
> ```
> Inbound:  TCP 443 from 0.0.0.0/0     (HTTPS from anywhere)
> Inbound:  TCP 80 from 0.0.0.0/0      (HTTP, redirects to HTTPS)
> Outbound: All traffic to app-sg        (forward to app servers)
> ```

> **App servers**
>
> ```
> Inbound:  TCP 8080 from alb-sg        (only from the load balancer)
> Outbound: TCP 5432 to db-sg           (connect to database)
> Outbound: TCP 443 to 0.0.0.0/0       (call external APIs via NAT)
> ```

> **Database**
>
> ```
> Inbound:  TCP 5432 from app-sg        (only from app servers)
> Outbound: None needed                  (database doesn't initiate connections)
> ```

**Notice the chain:** internet → ALB (443) → app (only from ALB) → database (only from app). Each layer only talks to its neighbor — the database cannot be reached from the internet, there's no path.

### 4.7 VPC Flow Logs

Captures metadata about IP traffic flowing through your VPC — source/destination IP, port, protocol, action (ACCEPT/REJECT), bytes transferred. Doesn't capture packet contents — it's metadata, not a packet capture.

Sent to CloudWatch Logs or S3. Essential for:

- Debugging connectivity issues ("why can't my app reach the database?")
- Security auditing ("who tried to access this subnet?")
- Compliance ("prove that no unauthorized traffic reached the database subnet")

### 4.8 Building the VPC by Hand — Step by Step

The practical exercise for Day 4. Do it in the console first to understand each component, then repeat via CLI to prove you can script it.

1. Create the VPC with CIDR 10.0.0.0/16
2. Create 6 subnets (public × 2 AZs, private-app × 2 AZs, private-db × 2 AZs)
3. Create and attach an Internet Gateway
4. Create a NAT Gateway in one public subnet (allocate an Elastic IP first)
5. Create route tables — public → 0.0.0.0/0 to IGW, associate with public subnets; private → 0.0.0.0/0 to NAT Gateway, associate with private subnets
6. Create security groups (ALB-sg, app-sg, db-sg) with the rules described above
7. Enable VPC Flow Logs to CloudWatch
8. Verify: launch a test instance in the public subnet, confirm internet access. Launch one in the private subnet, confirm it can reach the internet via NAT but cannot be reached from outside.

### 4.9 Why Each Component Exists — and What Breaks Without It

Now that you've built every piece, here's the full justification for each one — what it does, why it exists, and what fails if you remove it.

**How the pieces fit together**

Traffic path: Internet → Internet Gateway → VPC (`10.0.0.0/16` — `fahad-devops-vpc`)

| Tier | AZ-a (`ap-south-1a`) | AZ-b (`ap-south-1b`) |
| --- | --- | --- |
| Public | `10.0.1.0/24` — ALB (alb-sg), NAT Gateway | `10.0.2.0/24` — ALB (alb-sg) |
| Private app | `10.0.10.0/24` — EC2 (app-sg) | `10.0.11.0/24` — EC2 (app-sg) |
| Private DB | `10.0.20.0/24` — RDS (db-sg) | `10.0.21.0/24` — RDS (db-sg) |

- Public subnet — internet-facing (ALB, NAT)
- Private app subnet — reachable only from the ALB
- Private DB subnet — reachable only from the app tier

Only one NAT Gateway (in AZ-a) — a deliberate cost trade-off for this learning build; production would place one per AZ for redundancy.

#### VPC (fahad-devops-vpc — 10.0.0.0/16)

- **What it does** — Your private isolated network inside AWS. Nothing can enter or leave unless you explicitly allow it.

- **Why it exists** — Without a VPC, all your resources sit on a shared flat network. The VPC is the wall around your house — it defines what's inside your network and what's outside.

- **Without it** — You'd have to use the default VPC, which puts everything in public subnets with public IPs. Fine for testing; a security risk for production.

#### Public subnets (10.0.1.0/24, 10.0.2.0/24)

- **What they do** — Subnets where the route table points `0.0.0.0/0` to the Internet Gateway. Resources here can have public IPs and be reached from the internet.

- **Why they exist** — The ALB needs to receive traffic from users on the internet. The NAT Gateway needs internet access to relay traffic for private instances. These are the _only_ things that should be internet-facing.

- **Without them** — No way for users to reach your application — your ALB would have no internet connectivity.

- **Why two?** — One per AZ (ap-south-1a and ap-south-1b). If AZ-a goes down, the ALB in AZ-b keeps serving. This is high availability.

#### Application Load Balancer (fahad-alb)

- **What it does** — Sits in both public subnets, terminates TLS, and distributes incoming requests across healthy targets in the app subnets.

- **Why it exists** — Users need one stable DNS name to hit, not a shifting list of individual EC2 IPs. The ALB also health-checks targets — if the App instance in AZ-a stops responding, the ALB simply stops sending it traffic, no manual intervention needed.

- **Without it** — You'd expose EC2 instances directly to the internet (defeating the whole private-subnet design), or hand out individual instance IPs that break every time Auto Scaling replaces one.

- **Why registered in both public subnets?** — An ALB is inherently multi-AZ — AWS runs its nodes in every AZ you attach it to. Registering both public subnets gives it the same redundancy as the rest of the architecture, for free.

#### Private app subnets (10.0.10.0/24, 10.0.11.0/24)

- **What they do** — Subnets with no direct internet route. Traffic goes outbound only through the NAT Gateway.

- **Why they exist** — Your application servers don't need to be internet-facing. They receive traffic _only_ from the ALB, and reach the internet _only_ through NAT. Even if your app has a vulnerability, an attacker can't directly connect from the internet.

- **Without them** — You'd put app servers in public subnets with public IPs. Any misconfigured security group would expose them directly to the internet.

#### EC2 instances (Auto Scaling group, app-sg)

- **What they do** — Run the actual application code, one per AZ at minimum, launched through an Auto Scaling Group rather than as standalone instances.

- **Why Auto Scaling instead of a fixed instance?** — If an instance crashes or an AZ has issues, the ASG launches a replacement automatically in a healthy AZ — you don't get paged to manually relaunch a server at 2am.

- **Why they can only be reached through the ALB** — `app-sg` only allows inbound traffic from `alb-sg`. Even if you know an instance's private IP, you can't connect to it directly — traffic has to come through the load balancer, which is the only thing the security group trusts.

#### Private DB subnets (10.0.20.0/24, 10.0.21.0/24)

- **What they do** — The most isolated subnets. No internet route at all (or outbound-only via NAT for updates).

- **Why they exist** — Your database is the crown jewel — it holds all your customer data. It should _only_ be reachable from the app servers, nothing else. Not from the internet, not from your laptop, not from any other service.

- **Why separate from app subnets?** — So you can apply different security groups per tier. DB-sg only allows port 5432 from App-sg. Separate subnets also let you apply different NACL rules per tier.

#### RDS (db-sg)

- **What it does** — A managed relational database in the private DB subnets, holding the application's persistent data.

- **Why it exists** — `db-sg` allows inbound traffic only from `app-sg` on port 5432. The database has no route to the internet in either direction — nothing outside the app tier can reach it, and it can't reach out.

- **Without it** — You'd run your own database engine on EC2, taking on patching, backups, and failover yourself — the trade-off from the shared responsibility model in 3.2.

- **Why two DB subnets, one per AZ?** — So RDS Multi-AZ has somewhere to place a synchronous standby in AZ-b. If the primary in AZ-a fails, AWS promotes the standby automatically — the active-passive failover pattern from 2.6, applied at the database layer.

#### Internet Gateway (fahad-igw)

- **What it does** — The door between your VPC and the public internet. Bidirectional — traffic flows both in and out.

- **Why it exists** — Without it, nothing in your VPC can reach the internet, and no one on the internet can reach anything in your VPC. Your ALB wouldn't work, your users couldn't connect.

- **Without it** — A completely isolated VPC. Useful for extremely sensitive air-gapped workloads, but not for a web application.

- **Key detail** — One IGW per VPC. Fully managed by AWS — horizontally scaled, redundant, never a bottleneck.

#### NAT Gateway (fahad-nat)

- **What it does** — Sits in a public subnet, relays outbound traffic for private subnets. One-way — the internet can't initiate connections through it.

- **Why it exists** — Your app servers in private subnets need to reach the internet: downloading OS updates, calling external APIs (Stripe, SendGrid), pulling Docker images. NAT lets them do this without being directly reachable.

- **Without it** — Your private instances would be completely isolated — they couldn't install packages, call external services, or push metrics to external monitoring.

- **Why in a public subnet?** — The NAT needs internet access to relay traffic. It gets this through the IGW via the public route table. Putting it in a private subnet would create a chicken-and-egg problem — NAT needs internet to provide internet.

> **Cost warning**
>
> NAT Gateway is ~$32/month — the most expensive component in your VPC. Delete it when not studying. Also delete the Elastic IP after, or it charges too.

#### Route tables (fahad-public-rt, fahad-private-rt)

- **What they do** — Rules that tell traffic where to go. Every subnet is associated with one route table: "if the destination matches this CIDR, send it there."

- **Why they exist** — Without route tables, traffic inside the VPC wouldn't know how to reach the internet or other subnets. Route tables are the GPS of your network.

| Route table | Rule | Meaning |
| --- | --- | --- |
| **fahad-public-rt** | `10.0.0.0/16 → local` | Traffic within the VPC stays internal |
| `0.0.0.0/0 → IGW` | Everything else goes to the internet |  |
| **fahad-private-rt** | `10.0.0.0/16 → local` | Traffic within the VPC stays internal |
| `0.0.0.0/0 → NAT` | Everything else goes outbound through NAT |  |

> **Without them**
>
> Every subnet would use the VPC's main route table (which has only the `local` route). No internet access for anything.

#### Security groups (fahad-alb-sg, fahad-app-sg, fahad-db-sg)

- **What they do** — Stateful firewalls attached to individual resources. They define _who_ can talk to _whom_ on _which port_.

- **The chain** — Internet → ALB-sg (port 443) → App-sg (port 8080, only from ALB-sg) → DB-sg (port 5432, only from App-sg)

- **Without them** — Everything in the VPC could talk to everything else on any port. A compromised ALB could connect directly to the database.

- **Why reference security groups (not IPs)?** — If you wrote "allow from 10.0.1.0/24," you'd have to update it every time the ALB's IP changes. By referencing `ALB-sg` as the source, it automatically applies to anything that has ALB-sg attached — regardless of IP.

#### VPC Flow Logs

- **What they do** — Capture metadata about every network connection — source IP, destination IP, port, protocol, accept/reject, bytes. Sent to CloudWatch Logs.

- **Why they exist** — When something doesn't work ("my app can't reach the database"), flow logs tell you whether the traffic was attempted and rejected (security group issue) or never attempted (routing issue).

- **Without them** — Debugging network issues blind. "Is traffic being blocked or not reaching?" becomes a guessing game.

#### What about NACLs?

> **Deliberately skipped**
>
> This build kept every subnet's NACL at its AWS default (allow all in, allow all out) and did all the enforcement with security groups instead. Security groups already implement the exact alb → app → db chain from 4.6; stacking a second, stateless firewall on top adds real operational cost (remembering to open _both_ directions for every rule) without adding protection this architecture doesn't already have. Custom NACLs earn their place as a second layer at the public subnet boundary in stricter, compliance-driven environments — worth revisiting later, not required for this build.

#### How a user request flows through all these components

```
1. User types your-app.com
2. Route 53 resolves to ALB's IP
3. Request hits ALB in public subnet         (ALB-sg allows port 443)
4. ALB forwards to EC2 in private app subnet (App-sg allows from ALB-sg)
5. EC2 queries RDS in private DB subnet      (DB-sg allows from App-sg)
6. Response flows back: RDS → EC2 → ALB → user

If EC2 needs to call Stripe API:
7. EC2 → NAT Gateway → IGW → internet       (outbound only, no inbound)
```

> **The test**
>
> For each component, ask: "what breaks if I remove this?" If you can answer that for every piece, you understand the VPC. If you can't, re-read that component's section.

## Lab Log
*Evidence from the hands-on exercises*

### 01 AWS CLI Profile & Identity Verification

`IAM` · `CLI`

Configured a named profile per 3.6 AWS CLI with Named Profiles, then confirmed it with `get-caller-identity` — the "whoami" of AWS. Account ID, ARN, and User ID all came back as expected for the profile.

### 02 Budget Alarm Setup

`Billing`

Set alerts at 50% and 80% of the monthly budget per 3.5 Budget Alarm Setup, before touching anything that costs money.

### 03 First EC2 Instance via CLI

`ap-south-1` · `t3.micro` · `Terminated`

Launched an instance, tagged using the convention from 3.4 Tagging Strategy — tried both the console wizard and the CLI, to compare the two workflows.

#### Observations

- **IMDSv2: Required** — the instance came up with the secure metadata option already enforced (see 3.7, Instance Profiles and IMDSv2). No AllowV1 fallback to worry about.
- **State: Terminated** — this instance was launched and torn down as a CLI smoke test, not the one that will sit in the VPC being built in 4.8. VPC ID and Subnet ID show blank because AWS drops that networking detail from the console once an instance is terminated, not because it skipped a VPC — every EC2 instance launches into some VPC (the account's default VPC here, since none was specified with `--subnet-id`).
- Tags match the 3.4 convention exactly (`Environment`, `Project`, `Owner`, `CostCenter`, `ManagedBy`) — good for cost tracking and the "who left this running?" question, even on a throwaway instance.

> **Next**
>
> Re-launch into the hand-built VPC's public/private subnets per 4.8 once the subnets, route tables and security groups exist, so the instance actually lands somewhere purposeful instead of the default VPC.

### 04 Creating the VPC

`10.0.0.0/16` · `fahad-devops-vpc`

Built by hand per 4.8 — "VPC only" (no default subnets/route tables auto-created), named `fahad-devops-vpc`, CIDR set to the plan from 4.2. Resource map showed 0 subnets and 1 (main) route table before the next steps. DNS resolution and DNS hostnames were both left enabled — required for instances to get usable DNS names and to resolve AWS service endpoints from inside the VPC.

### 05 Creating the 6 Subnets

`2 AZs` · `3 tiers`

All six subnets from the 4.2 CIDR plan, created in one batch and confirmed **Available**.

#### Observations

- CIDRs match the plan exactly: `10.0.1.0/24` / `10.0.2.0/24` (public), `10.0.10.0/24` / `10.0.11.0/24` (app), `10.0.20.0/24` / `10.0.21.0/24` (DB) — see 4.9 for why each tier exists.
- All six still show the VPC's default (main) route table at this point — the public/private route tables in 4.4 haven't been created and associated yet.

### 06 Internet Gateway

`fahad-igw`

Created per 4.8.

> **Not done yet**
>
> The IGW is created but not attached — its VPC column is empty and state reads **Detached**. The other IGW in this list (**Attached**) belongs to a different, unrelated VPC. Next step: _Actions → Attach to VPC_, selecting `fahad-devops-vpc` — without that, the public route table in 4.4 has nothing to point `0.0.0.0/0` at.

### 07 NAT Gateway

`fahad-nat` · `fahad-public-a`

Created in `fahad-public-a` only, matching the single-NAT cost trade-off from 4.9 and 4.5's cost note.

> **Note**
>
> State shows **Pending** right after creation — NAT Gateways take a few minutes to become **Available**. It also has no primary public IP yet at this point, because the Elastic IP allocation step (4.8, step 4) hadn't finished attaching.

## A1 Checklist
*Week 1 Assignment A1 — Strategy Document Checklist*

Use this checklist to make sure your document covers every required element. Checks are saved in this browser only.

- [ ] **Branching model:** trunk-based development described, short-lived branches, feature flags for incomplete work
- [ ] **Rejected alternative:** Gitflow described with specific reasons it was rejected (merge conflicts, slow feedback, incompatible with daily deploys)
- [ ] **Release cadence:** daily deployments, automated from `main`
- [ ] **Deployment-strategy decision matrix:** table mapping each service class (stateless API, stateful service, database migration, frontend) to a strategy with justification
- [ ] **Environment and promotion diagram:** dev → staging → prod with gates between each, what differs and what must be the same
- [ ] **Multi-region topology:** active-passive or active-active, with the choice justified
- [ ] **RTO and RPO:** specific numbers with business justification
- [ ] **DORA baseline and targets:** 4 metrics with current baseline and 3-month targets
- [ ] **DORA measurement method:** how each metric will be tracked
- [ ] **Three IAM roles:** application, operator, auditor — each with full policy JSON and least-privilege justification
- [ ] **VPC architecture diagram:** CIDR plan, subnet layout, route tables, security group chains
- [ ] **All choices can be defended:** for every decision, name the rejected alternative and explain the trade-off

---

*Week 1 complete. Next: Week 2 — Compute, Networking, Data & Observability →*