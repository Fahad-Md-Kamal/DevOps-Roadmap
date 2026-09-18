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


