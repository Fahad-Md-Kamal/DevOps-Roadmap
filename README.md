# DevOps Ramp Plan

A hands-on DevOps ramp plan — from delivery principles and AWS foundations through containers, Terraform, and a real Jenkins CI/CD pipeline — learned by building the real thing rather than just reading about it.

**[Read the live site →](https://fahad-md-kamal.github.io/DevOps-Roadmap/)**

## What this is

Originally scoped as a structured, full-time ramp-up, but the site itself isn't tied to any particular month or year — it's organized by topic, not by calendar date, so it reads the same whenever you land on it.

Every page is built from real work, not a rewritten tutorial: real AWS resources actually provisioned, a real Terraform codebase, and a real Jenkins pipeline deploying a real application — including the mistakes made along the way and how they were actually diagnosed and fixed, kept in as teaching material rather than edited out.

## Topics

- **Delivery Principles** — The Three Ways, DORA metrics, SLOs and error budgets, deployment strategies, pipeline anatomy, multi-region architecture.
- **AWS Accounts & IAM** — Global infrastructure, shared responsibility, quotas, tagging, budgets, and IAM in depth.
- **Networking (VPC)** — A VPC built by hand: CIDR planning, subnets, route tables, security groups vs NACLs, flow logs.
- **Compute & Scaling** — EC2, golden AMIs, launch templates, Auto Scaling Groups and scaling policies.
- **Load Balancing & DNS** — ALB and NLB, health checks, TLS via ACM, Route 53.
- **Databases (RDS)** — Multi-AZ, read replicas, backups and point-in-time recovery, safe SQL operations.
- **Storage & Observability** — S3, Secrets Manager, CloudWatch, X-Ray, AWS Budgets.
- **Containers** — Production container images, ECS Fargate, deployment strategies, EKS fundamentals.
- **Terraform** — From `init`/`plan`/`apply` through modules, remote state, and a whole platform (VPC, ALB, ASG, RDS, ECS, EKS, Lambda) written in HCL.
- **Jenkins** — Controller/agent setup, connecting an SSH agent, pipeline configuration, and a full deployment pipeline built (and repeatedly broken and fixed) against a real application.
- **CI/CD & Delivery** — End-to-end pipeline design and progressive delivery.

## Repository layout

| Path | What it is |
|---|---|
| `docs/` | The site's content, as Markdown — one file per topic above. See `docs/README.md` for how to add or edit a page. |
| `zensical.toml`, `requirements.txt`, `.github/workflows/` | Site build/deploy configuration — [Zensical](https://zensical.org/) generates the static site, GitHub Actions builds and deploys it to GitHub Pages on every push to `main`. |
| `IaC/` | Real, working Terraform code written while learning the Terraform topic above. |
| `jenkins/` | Reference material from building the real Jenkins pipeline covered on the Jenkins page. |
| `scripts/` | Tooling used while building this repo (currently just the one-off HTML→Markdown migration script). |
