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
- **Containers** — Production container images: small, cacheable Dockerfiles, multi-stage builds, non-root users, ECR and image scanning.
- **ECS & EKS** — ECS Fargate, hands-on from the console through Terraform, EKS fundamentals, and the ECS-vs-EKS decision.
- **Deployment Strategies** — Blue/green with CodeDeploy, canary releases, and backward-compatible schema changes, done for real against ECS.
- **Terraform** — From `init`/`plan`/`apply` through modules, remote state, and a whole platform (VPC, ALB, ASG, RDS, ECS, EKS, Lambda) written in HCL.
- **Jenkins** — Controller/agent setup, connecting an SSH agent, pipeline configuration, and a full deployment pipeline built (and repeatedly broken and fixed) against a real application.
- **CI/CD & Delivery** — End-to-end pipeline design and progressive delivery.

## Further reading

One primary source per topic — no shopping around, just what was actually used while building this:

- **Principles & delivery** — *Accelerate* for the DORA metrics, *Continuous Delivery* for pipeline design, the Google SRE workbook's chapters on SLOs.
- **AWS** — an AWS Solutions Architect Associate course, AWS Skill Builder labs, the AWS Well-Architected whitepapers.
- **SQL** — [PG Exercises](https://pgexercises.com/) for query volume, *Use The Index, Luke* for reading query plans and indexes.
- **Containers & Kubernetes** — the AWS ECS Workshop, then the AWS EKS Workshop.
- **Terraform** — HashiCorp's own tutorials, the AWS provider registry docs, *Terraform: Up & Running* for module and state patterns.
- **Jenkins** — the Jenkins Handbook and the Pipeline syntax reference.

## What this deliberately doesn't cover

- **Linux administration and Git** — assumed prior knowledge, not taught here.
- **Observability and incident response as their own topic** — covered only where they come up naturally (CloudWatch inside Storage & Observability, log investigation inside the AWS pages), not as a dedicated deep dive.
- **EKS to full production depth** — the Containers page treats it at a fundamentals level: enough to run a service and compare it against ECS, not a production Kubernetes operations guide.
- **Kafka, Nagios, Akamai, Datadog, Grafana** — not covered. CloudWatch is the observability tool used throughout.

## Repository layout

| Path | What it is |
|---|---|
| `docs/` | The site's content, as Markdown — one file per topic above. See `docs/README.md` for how to add or edit a page. |
| `zensical.toml`, `requirements.txt`, `.github/workflows/` | Site build/deploy configuration — [Zensical](https://zensical.org/) generates the static site, GitHub Actions builds and deploys it to GitHub Pages on every push to `main`. |
| `IaC/` | Real, working Terraform code written while learning the Terraform topic above. |
| `jenkins/` | Reference material from building the real Jenkins pipeline covered on the Jenkins page. |
| `scripts/` | Tooling used while building this repo (currently just the one-off HTML→Markdown migration script). |
