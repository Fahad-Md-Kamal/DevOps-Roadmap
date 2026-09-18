---
title: Containers
icon: fontawesome/brands/docker
---

# Containers: ECS Fargate & EKS

## 10 Production Container Images

Building an image that's actually fit to run in production, not just to work on a laptop.

- A Dockerfile that's small and cacheable
- Multi-stage builds
- Non-root users
- Health endpoints
- Configuration through the environment, not baked into the image
- Tagging by commit
- ECR and image scanning
- A local multi-container stack to develop against


## 11 ECS Fargate

The serverless container runtime the customer's platform already runs on.

Amazon ECS (Elastic Container Service) is AWS's own container orchestrator — it schedules Docker containers onto compute, keeps a declared number of them running, replaces one that crashes, and wires them up to a load balancer, without needing a self-managed Kubernetes control plane (that's EKS's job, 13/14). Two launch types decide what actually runs the containers: **EC2** (your own Auto Scaling Group of instances — you size, patch, and pay for the underlying servers yourself) and **Fargate** (serverless — AWS runs the containers on its own infrastructure; you declare CPU and memory per task and there's no EC2 instance to manage at all). This project uses Fargate, which is why an entire category of host-level maintenance — AMI patching, instance right-sizing — never comes up here the way it does for the EC2-based compute in compute.md.

#### Specialty: what actually makes ECS different

ECS's core distinction from EKS is that there's no Kubernetes API involved at all — no `kubectl`, no YAML manifests, no separate cluster-autoscaler/ingress-controller ecosystem to install and keep patched. It's AWS's own proprietary scheduler, so it only ever runs on AWS, but in exchange it gets first-class, no-extra-setup integration with the rest of AWS: an IAM role attached directly to a task (the task role, in the bullet list below), an ALB target group registered automatically as tasks start and stop, logs shipped straight to CloudWatch, secrets pulled from Secrets Manager/Parameter Store at container start — all of it built in, none of it a separate Helm chart or operator to install and maintain.

!!! note "The tradeoff for that simplicity"

    Kubernetes' whole ecosystem — Helm charts, operators, a huge base of transferable knowledge and tooling — doesn't carry over to ECS at all, and neither does the workload itself: an ECS task definition doesn't run on GKE, AKS, or on-prem the way a Kubernetes manifest does. ECS is the simpler, faster-to-learn option specifically *because* it gives up that portability.

#### When to actually reach for it

| Situation | Better fit |
|---|---|
| Already fully committed to AWS, want to run containers without learning or operating a Kubernetes control plane | **ECS** — simplest path, least new machinery |
| Need portability across clouds, or already have Kubernetes expertise/tooling (Helm, existing operators) elsewhere | **EKS** (13/14) — same containers, a control plane that runs anywhere Kubernetes does |
| Short, bursty, event-driven work — a few seconds to a few minutes, no long-running process | **Lambda** — no cluster, no service to keep alive, billed per invocation |
| A handful of long-running services, steady load, no need for auto scaling or rolling deploys at all | Plain EC2, no orchestrator — fewer moving parts, but every restart/replace/rollout is manual |

#### Cost, compared

The orchestrator itself is not where ECS and EKS actually differ in price — the compute underneath (EC2 or Fargate) costs the same either way. The difference is the control plane:

| | Control plane cost | Compute cost |
|---|---|---|
| ECS | Free — no charge for the ECS scheduler itself | EC2 launch type (pay for the instances) or Fargate (pay per vCPU/memory-second) |
| EKS | About $0.10/hour per cluster (roughly $73/month), flat, regardless of how small the workload is | Identical EC2 or Fargate pricing underneath |
| Self-managed Kubernetes on plain EC2 | Free (no control-plane fee) | Same EC2 pricing, plus the engineering time to run and patch the control plane yourself |
| Lambda | None — no cluster at all | Per-invocation and per-millisecond; cheapest for infrequent or spiky work, most expensive per unit of *sustained* compute |

!!! danger "Fargate vs. the EC2 launch type isn't a flat 'Fargate always costs more' rule"

    Fargate charges a real premium per vCPU/memory-second over on-demand EC2 pricing for equivalent capacity — but that premium buys zero idle capacity, since Fargate only ever runs exactly what's requested, nothing more. A handful of small, spiky tasks that would otherwise sit on a mostly-idle EC2 instance are often cheaper on Fargate precisely because nothing is paid for while idle. Many tasks bin-packed tightly onto a small number of large, highly-utilized EC2 instances (or EC2/Fargate Spot capacity for either launch type) usually wins the other way. The right call depends on utilization, not on Fargate or EC2 being universally cheaper.

!!! success "What to actually know before touching any of the bullets below"

    A **cluster** is just a logical grouping — free, and mostly a namespace, not a piece of infrastructure by itself. A **task definition** is the blueprint (image, CPU/memory, ports, environment, IAM roles) — the ECS equivalent of a Docker Compose file. A **task** is one running instance of that blueprint. A **service** is what actually keeps a declared number of tasks running continuously, replacing one that dies and driving a rolling deployment — a cluster with no service running in it does nothing at all, it's just an empty namespace waiting for one.

- Clusters, task definitions and revisions, services
- Task role vs execution role
- CPU and memory sizing
- `awsvpc` networking and ENI limits
- ALB integration and service discovery
- Service auto scaling
- Rolling deployments and the deployment circuit breaker


## 12 ECS With Real Deployment Strategies

Three services routed by path, sharing a database — Week 1's deployment-strategy decision matrix applied for real.

- Blue/green deployment with CodeDeploy
- A canary release
- A schema change deployed backward-compatibly
- Deploy under load and prove zero dropped requests


## 13 EKS Fundamentals

The Kubernetes side of the ECS-vs-EKS conversation the customer keeps having.

- Control plane vs data plane
- Managed node groups vs Fargate profiles
- `kubectl` and contexts
- Pods, deployments, services, ingress
- ConfigMaps and secrets
- Requests and limits
- IRSA for pod-level IAM
- The horizontal pod autoscaler and the AWS Load Balancer Controller


## 14 ECS vs EKS, Decided

Deploy the same service to EKS behind an ALB ingress and perform a rolling update, then a troubleshooting clinic across both runtimes.

- Image pull failure
- Wrong subnet
- Missing permission
- Failing probe
- Out-of-memory kill
- Write the ECS-vs-EKS comparison

!!! note "Designated give"

    This Friday is the only flexible day in the month. If a public holiday or absence costs a day anywhere in September, it's taken from here — EKS drops to a single day and the comparison becomes a written exercise instead. AWS, Terraform and Jenkins weeks are never compressed.


