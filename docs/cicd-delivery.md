---
title: CI/CD & Delivery
icon: lucide/rocket
---

# CI/CD Pipeline & Progressive Delivery

## 21 CI and CD, End to End

The full path from commit to running service, plus the two operations jobs the customer names explicitly.

- Lint and test stages
- Container build and push to ECR tagged by commit
- `terraform fmt`, `validate` and `plan` posted onto the pull request
- The approval gate, `terraform apply`
- ECS service update with wait-for-stable, smoke tests
- A one-click rollback job, notifications
- Safe SQL execution inside a transaction, and log extraction for a time window


## 22 Progressive Delivery, Runbook, Readiness Review

Morning: finishing the pipeline. Afternoon: the readiness review itself.

- Blue/green and canary driven from the pipeline
- Migration step ordering around a deploy
- OIDC and IAM roles instead of static credentials
- Timeouts, retries and idempotency
- The operations runbook, written from what's been built
- Readiness review: live demo, architecture defence, customer-style questioning

!!! note "Known thinness"

    Three days is enough to build and operate this pipeline, not to design a delivery platform from nothing. Jenkins is targeted at L2 on 30 September and finishes during October's knowledge transfer, on the customer's own Jenkins, with the tech lead pairing.


