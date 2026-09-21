---
title: Deployment Strategies
icon: lucide/shuffle
---

# ECS With Real Deployment Strategies

## 12 ECS With Real Deployment Strategies

Three services routed by path, sharing a database — Week 1's deployment-strategy decision matrix applied for real.

- Blue/green deployment with CodeDeploy
- A canary release
- A schema change deployed backward-compatibly
- Deploy under load and prove zero dropped requests

#### Hands-on: blue/green with CodeDeploy

Built fresh, deliberately separate from [ecs](ecs.md)'s section 11 `learning-*` resources and from the `ecs-cluster-service`/`ecs-alb` Terraform folders, for two reasons: `learning-cluster` was already torn down in that section's own step 8, and CodeDeploy blue/green needs the ECS service's deployment controller set to `CODE_DEPLOY` **at creation time** — immutable afterward, and not something the existing Terraform sets up. This gets its own Terraform once the console mechanics below are confirmed working, the same order [ecs](ecs.md) followed.

##### 1. Create a cluster

Identical to [ecs](ecs.md) section 11 step 1 — **ECS console → Clusters → Create cluster**, name it `bluegreen-cluster`, Infrastructure → **Fargate only**.

##### 2. Two target groups, not one

The first genuinely new piece. **EC2 console → Target Groups → Create target group**, twice:

- `bluegreen-tg-blue` — type **IP addresses**, protocol HTTP, port `80`, health check path `/`.
- `bluegreen-tg-green` — identical settings, just the other name.

Both stay empty on creation (skip "Register targets," same as [ecs](ecs.md) section 11 — something else registers targets automatically). `bluegreen-tg-blue` is the one live in production initially; `bluegreen-tg-green` is where CodeDeploy stands up the new version before swapping traffic to it.
