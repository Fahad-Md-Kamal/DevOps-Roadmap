---
title: Home
---

# DevOps Ramp Plan

A hands-on DevOps ramp plan, learned by building the real thing rather than reading about it — real AWS resources, a real Terraform codebase, and a real Jenkins pipeline deploying a real application, with every mistake and fix kept in as teaching material.

Topics below are grouped by the original week they came from, so it's clear which section of the ramp plan each page covers — even though each one now lives on its own right-sized page instead of being squeezed into a fixed week.

## Week 1 — Principles & AWS Foundations

- **[Delivery Principles](principles.md)** — The Three Ways, DORA metrics, SLOs and error budgets, deployment strategies (with a hands-on comparison of five), pipeline anatomy, multi-region architecture.
- **[AWS Accounts & IAM](iam-accounts.md)** — Global infrastructure, shared responsibility, quotas, tagging, budgets, and IAM in depth: policies, roles, ARNs, condition keys.
- **[Networking (VPC)](networking.md)** — A VPC built by hand: CIDR planning, subnets, route tables, security groups vs NACLs, flow logs.

## Week 2 — Compute, Data & Observability

- **[Compute & Scaling](compute.md)** — EC2, golden AMIs, launch templates, Auto Scaling Groups and scaling policies.
- **[Load Balancing & DNS](load-balancing-dns.md)** — ALB and NLB, health checks, TLS via ACM, Route 53.
- **[Databases (RDS)](databases.md)** — Multi-AZ, read replicas, backups and point-in-time recovery, safe SQL operations.
- **[Storage & Observability](storage-observability.md)** — S3, Secrets Manager, CloudWatch, X-Ray, AWS Budgets.

## Week 3 — Containers

- **[Containers](containers.md)** — Production container images, ECS Fargate, deployment strategies, EKS fundamentals.

## Week 4 — Terraform

- **[Terraform](terraform.md)** — From `init`/`plan`/`apply` through modules, remote state, and a whole platform (VPC, ALB, ASG, RDS, ECS, EKS, Lambda) written in HCL.

## Week 5 — Jenkins & Delivery

- **[Jenkins](jenkins.md)** — Controller/agent setup, connecting an SSH agent, pipeline configuration, and a full real deployment pipeline built (and repeatedly broken and fixed) against a real application.
- **[CI/CD & Delivery](cicd-delivery.md)** — End-to-end pipeline design and progressive delivery.
