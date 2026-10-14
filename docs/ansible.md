---
title: Ansible
icon: simple/ansible
---

# Ansible

A roadmap, not a build log — the rest of this site teaches by building a real thing and keeping every mistake in as material; this page is laid out before any of that hands-on work happens, so it's explicitly a study plan: what to learn, in what order, how to practice it against infrastructure this project already has, which sources are actually authoritative, and exactly which exams make up Red Hat's Ansible certification track today.

### 23.1 Why Ansible, Alongside Terraform

[Terraform](terraform.md) answers "what infrastructure should exist" — it provisions the VPC, the EC2 instances, the RDS database, and tracks all of it as state. Ansible answers a different question: "what should be configured, once that infrastructure exists." It's a **configuration management** tool, not a provisioning one — agentless (it reaches a target purely over SSH or WinRM, no daemon to install first), push-based (the control node decides when something runs, rather than an agent polling for work), and idempotent by convention (a module's whole contract is "converge the target to this state, do nothing if it's already there" — the same idempotency principle Terraform's own `plan`/`apply` cycle is built around, just enforced per-module instead of via a tracked state file).

In practice the two are usually chained, not chosen between: Terraform provisions the EC2 instances from [compute.md](compute.md), and Ansible is what then installs packages, drops config files, creates users, and deploys the application onto them — either from a dynamic inventory built straight from Terraform's own output, or from the `amazon.aws.aws_ec2` inventory plugin querying AWS directly (23.2, 23.3).

### 23.2 The Core Curriculum — What To Actually Learn

This list is deliberately shaped like the real exam objectives (23.5) rather than an arbitrary tutorial order — EX294 and EX374 are, between them, as good a syllabus as exists for "what a working Ansible engineer actually needs."

`Inventory`
:   The list of managed nodes Ansible operates against — a static `.ini`/`.yaml` file to start, `group_vars`/`host_vars` for per-host or per-group data, and eventually a **dynamic inventory plugin** (`amazon.aws.aws_ec2`) that queries AWS directly instead of hand-maintaining a host list that drifts the moment an Auto Scaling Group changes size.

`Modules & ad-hoc commands`
:   A module is one idempotent unit of work (`ansible.builtin.package`, `ansible.builtin.service`, `amazon.aws.ec2_instance`, hundreds more). An ad-hoc command runs exactly one module against the inventory with no playbook at all — `ansible web -m ping`, `ansible web -a "systemctl status nginx"` — the fastest way to answer "is this true right now across my fleet" without writing anything down.

`Playbooks, plays & tasks`
:   A playbook is a YAML file of **plays**; each play targets a group from the inventory and runs an ordered list of **tasks**, each task invoking one module. This is the unit everything else below builds on.

`Variables & facts`
:   Data a playbook depends on — set in inventory, in `group_vars`/`host_vars`, passed with `-e`, or discovered automatically as **facts** (`ansible_facts`, gathered from the target itself at the start of a play unless `gather_facts: false`). Precedence between all these sources is one of the genuinely fiddly parts of real Ansible work, and worth deliberately studying rather than discovering by accident.

`Loops & conditionals`
:   `loop:` to run a task once per item in a list; `when:` to skip a task based on a fact or variable. Together these turn a flat task list into something that actually branches per-host.

`Handlers & notify`
:   A handler is a task that only runs if something **notified** it — the standard "restart nginx, but only if its config actually changed" pattern, run once at the end of a play even if multiple tasks notified it.

`Error handling`
:   `block`/`rescue`/`always` (direct parallel to `try`/`except`/`finally`), plus `ignore_errors` and `failed_when` for telling Ansible a module's own notion of "failed" isn't the one that actually matters here.

`Templates (Jinja2)`
:   The `template` module renders a `.j2` file with full Jinja2 — variables, conditionals, loops — into a real config file on the target. This is how a single template produces a correct `nginx.conf` for every environment, instead of hand-maintaining one file per environment.

`Roles`
:   A standard directory layout (`tasks/`, `handlers/`, `templates/`, `defaults/`, `vars/`, `meta/`) that packages a reusable unit of automation — the exact same motivation as extracting a [Terraform module](terraform.md#164-module-interface-design): once the same handful of tasks shows up in a second playbook, that's the signal to stop copy-pasting YAML and extract a role instead.

`Ansible Vault`
:   Encrypts a variables file (or any file) at rest with a password or a KMS-backed key, so a secret can live in git without living in git *in plaintext* — the same non-negotiable rule [jenkins.md's credentials store](jenkins.md#209-plugin-hygiene-the-credentials-store-folder-level-security) and Terraform's Secrets Manager integration already enforce elsewhere in this project, just enforced at the file level instead of per-value.

`Collections & Galaxy`
:   A collection bundles modules, roles, and plugins for distribution (`amazon.aws`, `community.general`, hundreds more); `ansible-galaxy collection install` pulls one down, and [galaxy.ansible.com](https://galaxy.ansible.com) is where to go looking for one before writing a module from scratch.

`ansible.cfg`
:   The behavior-configuration file (inventory path, default remote user, SSH settings, retry/fact-caching behavior) — read from several possible locations in a defined precedence order, the same kind of "where did this setting actually come from" question Terraform's own `*.tfvars` precedence raises.

`ansible-navigator` & Execution Environments
:   The current, container-based way to actually run a playbook: an **Execution Environment** is a container image bundling a specific Ansible version, Python dependencies, and collections, built with `ansible-builder`; `ansible-navigator run` executes a playbook inside one. This replaces "whatever happens to be pip-installed on the control node" with something as reproducible as the Docker images [containers.md](containers.md) already builds for the application itself.

`Automation Controller & Automation Hub`
:   Ansible Automation Platform's web UI/API layer — job templates, scheduling, RBAC, credential storage, and a private collection registry (Automation Hub) for content that shouldn't go to public Galaxy. This is the layer EX467 tests specifically, and the one "running Ansible" means once an organization moves past a single engineer's laptop.

### 23.3 A Practice Roadmap, Built on What's Already Here

Mirroring this site's own "learned by building the real thing" approach — every step below can run against real AWS infrastructure, reusing what [compute.md](compute.md) and [terraform.md](terraform.md) already cover, rather than a disposable local VM that teaches nothing about the environment this project actually operates in.

1. **Stand up 2–3 small EC2 instances as managed nodes** — reuse an existing AMI/launch template from compute.md, or a couple of plain `t3.micro`s is enough. Confirm SSH access works the same way it already does for any other EC2 instance in this project.
2. **Ad-hoc commands first, no playbook yet** — a static `inventory.ini`, then `ansible all -i inventory.ini -m ping` to confirm connectivity, `ansible all -m setup` to see exactly what facts are available before writing anything that depends on them.
3. **First playbook: install and configure nginx on a `web` group.** Run it twice in a row and actually look at the changed-task count on the second run — zero changes is the idempotency contract made visible, not just a claim.
4. **Add a template and a handler** — a Jinja2 `nginx.conf.j2` rendered with a variable, `notify: restart nginx` firing only when that template actually changes.
5. **Refactor into a role** once the playbook has more than one responsibility — same judgment call as extracting a Terraform module: wait for the second real use, don't pre-abstract the first one.
6. **Encrypt something real with Ansible Vault** — an application DB password or API key, referenced from a template. Compare directly against how the same problem is solved in [jenkins.md](jenkins.md#209-plugin-hygiene-the-credentials-store-folder-level-security)'s credentials store — same problem, different tool, same non-negotiable answer.
7. **Replace the static inventory with `amazon.aws.aws_ec2`** — a dynamic inventory plugin querying this project's real AWS account, grouped by tag, so a new instance shows up automatically instead of needing a manually-edited `inventory.ini`.
8. **Build and run inside an Execution Environment** — `ansible-builder build`, then `ansible-navigator run` the same playbook through it, instead of whatever happens to be installed locally. This is the exact shift EX374 tests for, and the one that matters most once more than one person runs these playbooks.

### 23.4 Study Sources

| Source | What it's actually good for |
|---|---|
| [docs.ansible.com](https://docs.ansible.com) | The canonical, authoritative module/plugin/collection reference — the first place to check a module's exact parameters, not the last. |
| [Red Hat's EX294 objectives page](https://www.redhat.com/en/services/training/ex294-red-hat-certified-engineer-rhce-exam-red-hat-enterprise-linux-9) | The exact, current skills tested for the RHCE-Ansible exam (23.5) — worth reading before any other study material, since it's the actual target. |
| [Red Hat's EX374 objectives page](https://www.redhat.com/en/services/training/red-hat-certified-specialist-developing-automation-ansible-automation-platform-exam) | Same, for the AAP-focused specialist exam — collections, execution environments, automation controller. |
| *Ansible for DevOps* by Jeff Geerling | The most widely recommended independent book — written by a long-time, well-known Ansible contributor, not a vendor marketing arm. |
| [Ansible Galaxy](https://galaxy.ansible.com) | Reading well-maintained, widely-used published roles is a better way to learn real structure and conventions than writing a role from zero with no reference. |
| Red Hat Learning Subscription — courses AU294/RH294 (feeds EX294) and AU374 (feeds EX374) | Official vendor training tied directly to specific exams, if a budget for it exists — not required, since Red Hat itself says comparable experience is an accepted substitute for every exam below. |

!!! note "Last verified October 2026 — re-check before relying on any exam detail"

    Red Hat periodically reorganizes its certification lineup (the Ansible Engine → Ansible Automation Platform rebrand retired and renamed several exams over the past few years), and exam objectives are versioned against a specific product release that changes over time. Everything in 23.5 was checked directly against Red Hat's own certification and exam pages as of this writing — confirm against those same pages before scheduling anything, rather than trusting a snapshot that will eventually drift.

### 23.5 The Red Hat Ansible Certification Roadmap

Ansible is a Red Hat product, so Red Hat is the only vendor certification body for it — there's no neutral third-party equivalent the way, say, the Linux Foundation sits alongside a cloud vendor's own certifications.

| Exam | Name | Role |
|---|---|---|
| EX200 | Red Hat Certified System Administrator (RHCSA) | Foundational RHEL exam — not Ansible-specific, but the required pairing for every path below. |
| EX294 | Red Hat Certified Engineer exam, Ansible track (also titled "Red Hat Certified Advanced System Administrator in Ansible Exam" on Red Hat's own site — see the note below) | Paired with EX200 to earn **RHCE, Ansible specialization**. Playbooks for day-to-day RHEL system administration: packages, services, firewall rules, storage, users, security — the RHCSA task list, automated. |
| EX374 | Red Hat Certified Specialist in Developing Automation with Ansible Automation Platform | Collections, execution environments, dynamic inventories from identity/database sources, automation controller — the advanced, AAP-platform-aware exam. 4-hour, lab-based, no multiple choice. |
| EX417 | Red Hat Certified Specialist in Microsoft Windows Automation with Ansible | Managing Windows targets with Ansible specifically — a narrower, platform-specific specialist exam. |
| EX457 | Red Hat Certified Specialist in Ansible Network Automation | Centrally managing network devices (switches, routers, firewalls) with Ansible instead of RHEL/Windows hosts. |
| EX467 | Red Hat Certified Specialist in Managing Automation with Ansible Automation Platform | Administering automation controller and automation hub at scale — the "running Ansible as a platform for a whole organization" exam, closest to 23.2's Controller/Hub entry. |

``` mermaid
flowchart TD
    EX200["EX200<br/>RHCSA"] --> EX294["EX294<br/>Ansible Automation"]
    EX294 --> RHCE["RHCE, Ansible specialization<br/>EX200 + EX294"]

    RHCE --> EX374["EX374<br/>Developing Automation w/ AAP"]
    RHCE --> EX417["EX417<br/>Windows Automation"]
    RHCE --> EX457["EX457<br/>Network Automation"]
    RHCE --> EX467["EX467<br/>Managing Automation w/ AAP"]

    EX374 --> RHCA["RHCA -- Ansible Architect track<br/>any 3 of the 4 specialist exams"]
    EX417 --> RHCA
    EX457 --> RHCA
    EX467 --> RHCA
```

!!! danger "RHCE is not one exam, and EX294 alone doesn't earn it"

    "Get RHCE" is frequently shorthand for "pass EX294," but Red Hat's own certification page is explicit that RHCE is earned per specialization, each requiring **two** exams: EX200 + EX294 for the Ansible track, EX200 + EX342 for the Enterprise Linux track, and separate pairs again for OpenShift and cloud-native applications. EX294 by itself, without a current EX200 already on file, does not earn RHCE.

!!! note "Red Hat's own site names EX294 two different things"

    The certification overview page's featured section calls it the "Red Hat Certified Engineer exam"; the same page's Ansible-track requirements list calls it the "Red Hat Certified Advanced System Administrator in Ansible exam." Both refer to the identical exam code, EX294 — this is Red Hat's own inconsistent labeling, not two different exams, and not a mistake in this page.

!!! success "A reasonable order, starting from zero"

    EX200 (RHCSA) first — it's the shared prerequisite for everything else here. Then EX294, which earns RHCE in the Ansible track and is, objective-for-objective, the best-aligned exam with 23.2's core curriculum. EX374 next if the goal is depth in the AAP-platform side (collections, execution environments, controller) rather than breadth — and only then, if RHCA is the actual target, any three of EX374/EX417/EX457/EX467, picked by whichever specialization (Windows fleets, network devices, or platform administration) actually matches the work being done.
