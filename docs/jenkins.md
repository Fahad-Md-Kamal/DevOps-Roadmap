---
title: Jenkins
icon: fontawesome/brands/jenkins
---

# Jenkins Provisioned, Pipeline as Code

Standing up Jenkins itself, then writing pipelines as code from day one.

### 20.1 Controller & Agent Model

Jenkins splits into two roles. The **controller** (formerly "master") serves the web UI, stores every job's configuration, schedules builds, and holds the plugin/credential state — it orchestrates, it doesn't build. An **agent** (formerly "slave"/"node") is a separate machine or container that connects to the controller and actually runs the pipeline's steps.

!!! danger "Never build directly on the controller"

    The controller has no isolation from what runs on it — a build that exhausts memory, hangs, or gets compromised takes down the one thing coordinating every other job too. Agents exist specifically to keep build workloads (arbitrary code, effectively) away from the process that everything else depends on staying up.

An agent advertises **labels** — arbitrary tags like `linux`, `docker`, or `gpu` — and a pipeline's `agent` directive picks one by label, the same way a Kubernetes pod picks a node by `nodeSelector`:

``` groovy
pipeline {
  agent { label 'linux && docker' }
  stages { stage('Build') { steps { sh 'make build' } } }
}
```

!!! success "Why not just one big controller"

    Separate agents mean a Windows build and a Linux build can run on the same Jenkins instance without one machine needing both toolchains installed, and adding build capacity is "add another agent," not "resize the box everything else depends on." The controller stays a stable, mostly-idle coordination point regardless of how much build traffic the team generates.

#### Why agents exist, beyond just isolation

| Reason | What it actually buys |
|---|---|
| Isolation | Arbitrary, untrusted build code never runs on the one process everything else depends on (the fact-fail above). |
| Horizontal scaling | More build capacity is "provision another agent," not "give the controller a bigger instance" — capacity and coordination scale independently. |
| Environment matching | A label picks the toolchain a build actually needs — a specific OS, a GPU, a licensed tool only installed on one machine — instead of forcing every build to fit whatever the controller happens to have. |
| Parallelism | Multiple agents mean multiple builds genuinely running at once, not queued behind each other on a single executor. |
| Network/resource proximity | An agent can live inside the same VPC, region, or on-prem network as whatever it needs to reach fast — an internal artifact repo, a private database, a specific compliance boundary — without routing the controller itself into that network. |
| Team/security segregation | Folder-scoped agents (20.9) let one team's builds run on infrastructure another team can't touch, without needing a separate Jenkins instance per team. |

#### Types of agents

| Type | How it connects / how long it lives |
|---|---|
| Static (permanent) agent | Added once by hand via **Manage Jenkins → Nodes** and left running indefinitely — one real, named machine (20.3's EC2 example). Simple, but it's idle capacity paid for even when no build is using it. |
| SSH (outbound) agent | The controller initiates the connection, over SSH, to a host it already knows the address of (20.3). Needs the agent host reachable from the controller, not the other way around. |
| Inbound (JNLP/WebSocket) agent | The agent initiates the connection *to* the controller instead — the fix when the agent sits behind NAT or a firewall the controller can't reach inbound, e.g. a build machine on a laptop or in a restricted network. |
| Cloud / ephemeral agent | Provisioned on demand by a plugin (EC2 Fleet, Docker, Kubernetes) when a build needs one, then torn down afterward. No idle cost, and every build starts from a known-clean environment instead of accumulating drift on a long-lived machine. |
| Docker agent | Declared directly in a Jenkinsfile — `agent { docker { image 'node:20' } }` — a fresh, disposable container per build or per stage, with the exact toolchain version pinned in code instead of installed once on a static machine. |
| Built-in node | The controller's own, hidden executor pool — technically able to run builds itself, which is exactly what the fact-fail above says not to rely on. Usually set to 0 executors deliberately on any real controller. |

### 20.2 Installing Jenkins & First-Time Setup

Before anything gets provisioned as code (20.4), it's worth knowing what "installing Jenkins" actually involves by hand — the same principle as terraform.html starting from `ssh-keygen` and a plain resource block before ever reaching a module. Jenkins is a Java application; everything below assumes Java is present first.

| Method | Command | Good for |
|---|---|---|
| Native package (Amazon Linux/RHEL) | `dnf install jenkins`, after adding the Jenkins repo | A long-lived controller on a real instance — this project's approach (20.4) |
| Native package (Debian/Ubuntu) | `apt-get install jenkins`, after adding the Jenkins `apt` repo and signing key | Same idea, different AMI family — the exact `dnf`/`apt-get` distinction from 18.8.1, applied to Jenkins itself now |
| Docker | `docker run -p 8080:8080 -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts` | Trying Jenkins locally, or running it as a container on ECS/EKS instead of a bare EC2 instance |
| WAR file | `java -jar jenkins.war` | Quick, throwaway testing — nothing installed system-wide, nothing left behind but the process |

``` bash
#!/bin/bash
# Amazon Linux / RHEL family
dnf install -y java-17-amazon-corretto
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins
systemctl enable --now jenkins
```

``` bash
#!/bin/bash
# Debian / Ubuntu family
apt-get update
apt-get install -y fontconfig openjdk-17-jre
wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | tee /etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install -y jenkins
```

!!! note "Java version is a real compatibility constraint"

    Recent Jenkins releases require Java 17 or 21 — an older Java 11 install fails to even start the service, with the actual reason buried in `systemctl status jenkins` or `/var/log/jenkins/jenkins.log` rather than shown anywhere obvious. Check the specific Jenkins version's requirements before assuming whatever Java happens to already be on an AMI is new enough.

#### First-time setup wizard

Jenkins starts on port 8080 by default and, on first boot, is locked behind a one-time password only readable from the server itself:

``` bash
cat /var/lib/jenkins/secrets/initialAdminPassword
```

Unlock Jenkins
:   Paste that password into the setup wizard at `http://<controller-ip>:8080` — proves whoever's completing setup actually has access to the server itself, not just the network port.

Install plugins
:   "Install suggested plugins" is the reasonable default for a first controller — a curated set covering Git, pipelines, and the essentials. "Select plugins to install" is the deliberate route once 20.5's plugin-hygiene principle actually matters — smaller footprint, chosen instead of inherited.

Create the first admin user
:   Skipping this and continuing as the default `admin` account is explicitly offered but shouldn't be taken for anything beyond a five-minute local test — the same reasoning as never leaving a database on its default credentials.

Instance configuration
:   Confirms the URL Jenkins believes it's reachable at — matters later for webhook payload URLs (20.11) and any notification that links back to a build, since a wrong URL here means links that go nowhere.

#### Operating Jenkins as a systemd service

The native package installs Jenkins as a real systemd unit, not just a process someone starts by hand — the same start/stop/status vocabulary as any other Linux service applies directly:

``` bash
systemctl start jenkins      # start it now
systemctl stop jenkins       # stop it now
systemctl restart jenkins    # e.g. after a config or plugin change that needs a restart
systemctl status jenkins     # is it actually running, and since when
systemctl enable jenkins     # survive a reboot -- already done by --now during install
journalctl -u jenkins -f     # follow the service's own logs live
```

Two files control how the service actually behaves, separate from anything configured in the Jenkins UI itself:

`/etc/sysconfig/jenkins` (RHEL family) / `/etc/default/jenkins` (Debian family)
:   Environment variables read by the systemd unit before Jenkins even starts — `JENKINS_PORT` (default 8080), `JENKINS_HOME` (where job data actually lives), `JENKINS_USER` (which OS user the process runs as). Changing the port here, not in the Jenkins UI, is what actually takes effect — the UI has no setting for its own listen port.

`JAVA_OPTS` / `JENKINS_JAVA_OPTIONS`
:   JVM flags passed to the underlying Java process — heap size (`-Xmx2g`), most commonly, since Jenkins is a long-running JVM and the default heap can be too small for a controller running many jobs.

!!! danger "A config file change needs a restart, not a reload"

    Neither of the files above is watched live — editing `JENKINS_PORT` or `JAVA_OPTS` and expecting it to take effect immediately is the same mistake as expecting a changed environment variable to reach an already-running process anywhere else. `systemctl restart jenkins` is what actually applies it.

!!! success "Verifying it actually worked"

    `systemctl status jenkins` showing `active (running)`, plus the setup wizard actually loading in a browser on port 8080, is the full confirmation — no separate health check exists beyond "does the service report running and does the UI respond."

!!! note "Provisioning this with Terraform lives in the Terraform week"

    Wrapping this exact install script into an `aws_instance`'s `user_data`, with `JENKINS_HOME` on its own EBS volume for durability, is covered in terraform.html 18.10 — that's fundamentally a Terraform/infrastructure topic (provisioning compute), not a Jenkins-specific one, so it lives with the rest of Week 4's real resource patterns rather than here.

### 20.3 Connecting an Agent Node via SSH

A controller with no agents attached still has nowhere to actually run a build (20.1). **Manage Jenkins → Nodes → New Node** creates one — "Permanent Agent" for a real, long-lived machine like an EC2 instance, as opposed to a cloud-provisioned, one-build-and-gone agent. The SSH launch method needs nothing pre-installed on the target beyond SSH access and a working Java — the controller pushes its own agent jar over the connection itself.

![Jenkins node Configure screen: Name agent-one, Remote root directory /home/ec2-user, Labels agent-one, Launch method Launch agents via SSH, with Host and Credentials fields](images/jenkins/agent-connecting-configs.png)

*A permanent agent node's Configure screen — SSH launch method, pointed at one EC2 instance*

Name
:   The node's identity inside Jenkins — shown in build history and node listings, independent of the label used to target it.

Remote root directory
:   Where the agent jar and every job's workspace get written on the remote machine — `/home/ec2-user` above, which is also why the earlier pipeline output showed `Running on agent-one in /home/ec2-user/workspace/CICD`.

Labels
:   What a pipeline's `agent` directive (20.1) actually matches against — set to `agent-one` here, matching the node's own name, but the two are independent; a label can be shared across several nodes, or differ from the node's name entirely.

Usage
:   "Use this node as much as possible" lets the controller schedule any matching job here; the alternative, "Only build jobs with label expressions matching this node," reserves it for jobs that explicitly ask for it and nothing else.

Launch method: Launch agents via SSH
:   Host and Credentials (an SSH keypair, added to Jenkins' credentials store — 20.9) are all this method needs. Jenkins opens the connection itself on save, or whenever the node is manually relaunched.

#### What actually happens when it connects

``` text
[SSH] Opening SSH connection to <agent-host>:22.
[SSH] Authentication successful.
[SSH] Starting sftp client.
[SSH] Copying latest remoting.jar...
[SSH] Starting agent process: cd "/home/ec2-user" && java -jar remoting.jar -workDir /home/ec2-user
Agent successfully connected and online
```

Underneath the UI, this is exactly the SSH-file-transfer-plus-remote-command pattern from terraform.html's own `ssh-keygen`/`scp` fundamentals — Jenkins just automates it: connect, copy its agent jar over SFTP, then run it with `java -jar` on the other end.

!!! danger ""java: command not found" here means Java is missing, not Jenkins misconfigured"

    The SSH connection and the SFTP copy can both succeed — the log shows authentication working and `remoting.jar` transferring cleanly — and the launch can still fail at the very last step, `bash: line 1: java: command not found` / `Agent JVM has terminated. Exit code=127`, because there's simply no `java` on the agent host's `PATH`. A common real cause: a boot-time install script (this project's own 20.2/terraform.html 18.10 pattern) that ran `dnf install`/`yum install` without `-y` — harmless interactively, but silently skipped during a non-interactive `user_data` boot with no terminal to answer its confirmation prompt. Fix on the agent host directly (install Java, or relaunch the instance with the corrected script) — nothing about this is a Jenkins-side problem.

#### Referencing the node from a pipeline

``` groovy
pipeline {
    agent { label 'agent-one' }
    stages {
        stage('Hello') { steps { echo 'Hello World' } }
    }
}
```

!!! danger "An unquoted label is Groovy math, not a string"

    `agent { label agent-one }` — no quotes — doesn't fail because of anything wrong with the label. Groovy parses the bareword `agent-one` as the expression `agent - one`, subtracting two undefined variables, which throws `groovy.lang.MissingPropertyException: No such property: agent` from inside Jenkins' own `ModelInterpreter.inDeclarativeAgent` — a genuinely confusing error for what's really just a missing pair of quotes. `label 'agent-one'` is the fix, same as quoting any other Groovy string.

!!! note ""Still waiting to schedule task ‘agent-one’ is offline""

    A pipeline whose `agent` label matches only a currently-disconnected node queues indefinitely — there's no default timeout. **Manage Jenkins → Nodes →** that node shows its live status and log; clicking **Launch agent** retries the SSH connection without touching the pipeline itself, and an already-queued build picks up automatically the moment the node comes back online. On a memory-constrained instance (a `t3.micro`'s 1GB strained by a JVM plus the remoting process), a node can connect successfully and then drop again shortly after — `dmesg | grep -i kill` on the agent host is worth checking for an OOM kill if that keeps happening.

#### A node that's "online" but still fails every build

Two more failure modes worth knowing, both diagnosed on this same real agent — neither one looks like a connection problem at first, and neither one is fixed by the "Launch agent" click above.

!!! danger "A fix applied after the agent connected doesn't apply until it reconnects"

    Adding `ec2-user` to the `docker` group (`usermod -aG docker`) fixes the account immediately — a brand-new SSH login, or even `id ec2-user`, shows it right away. But Linux fixes a process's supplementary groups at the moment it's *created*, not continuously — the agent's already-running `remoting.jar` process keeps failing with `permission denied` on `/var/run/docker.sock` forever, because it was forked before the fix existed. Confirmed here directly: `ps -o etime= -p <pid>` showed the process had been alive for 48 minutes, well before the group was added. The fix isn't re-running the build — it's forcing a new process: **Manage Jenkins → Nodes → agent-one → Disconnect**, wait for it to show offline, *then* **Launch agent**. Clicking "Launch agent" while Jenkins still considers the node connected is often a no-op, since Jenkins has no reason to kill a channel it doesn't believe is broken.

!!! note "The identical symptom, from a completely different cause, on a freshly-launched instance"

    The same "permission denied" error can reappear on a brand-new instance too — even though `usermod -aG docker` is baked into `user_data` (20.2) and should have already run. The reason: `user_data` executes asynchronously in the background after boot, and SSH typically becomes reachable *before* it finishes — especially with a `yum update -y` running first, which alone can take over a minute. If Jenkins' agent connects and starts its process during that window, it's fixed at the pre-`usermod` state, for a boot-timing reason rather than a manual-fix-timing reason. Same fix either way: Disconnect, wait, Launch agent — by the time you're re-attempting, `user_data` has almost always finished.

!!! note ""Disk space is below threshold" when the disk isn't actually full"

    Jenkins' built-in **Free Temp Space** monitor took this same agent offline with "Only 456.59 MiB out of 456.62 MiB left on /tmp" — which reads like a full disk, but `df -h` on the box told a different story: `/tmp` was a `tmpfs` (RAM-backed) at 0% used, completely empty, while the real root disk had gigabytes free. The catch: this `t3.micro`'s `/tmp` is sized to roughly half its 1GB of RAM — a hard ceiling around 457MB that can never satisfy the monitor's default 1GiB-free requirement, no matter how empty it is. Not a leak, not real pressure — an instance-sizing mismatch against a monitor default. Fixed via the small gear/settings icon on the **Manage Jenkins → Nodes** list (or **Manage Jenkins → System**'s "Free Temp Space" section): lower the threshold to something the instance can actually reach, e.g. `100MiB`.

### 20.4 Job Types: What "New Item" Actually Offers

Clicking **New Item** in Jenkins shows every kind of thing it can create, in one screen — worth knowing the full list before defaulting to whichever one a tutorial happened to use. An overview for now; each gets its own use-cases/pros-cons/step-by-step treatment later.

| Item type | What it's for |
|---|---|
| Pipeline | Build, test, and deploy using a `Jenkinsfile` (20.10). Supports stages, parallel work, and running steps across multiple agents. |
| Freestyle project | The classic, UI-configured job type — checks out from up to one SCM, runs build steps serially, then post-build actions like archiving artifacts or sending email. Predates Pipeline-as-code, and still its own CJE exam section (20.11). |
| Multi-configuration project | One job definition run across many combinations automatically — multiple OSes, multiple environments, multiple platform targets — without hand-creating a separate job per combination. |
| Folder | A real namespace, not just a filter — two items can share a name if they live in different folders. The same folder that scopes credentials and permissions in 20.5. |
| Multibranch Pipeline | Scans one repository and creates a Pipeline job per detected branch and pull request automatically (20.10) — no manually creating a job per branch. |
| Organization Folder | One level up from Multibranch Pipeline — scans an entire GitHub org/Bitbucket project for repositories, and creates a Multibranch Pipeline for each one it finds. |

!!! note ""Duplicate an existing item" isn't a type"

    It's the seventh option on the same screen, but it's a shortcut action, not a job type of its own — it just copies an existing item's configuration into a new one, for any type above, as a starting point instead of configuring from scratch.

### 20.5 Pipeline Job Configuration: General, Triggers & the Script Definition

Choosing "Pipeline" as the item type (20.4) opens this configuration screen — the same shape every Pipeline job shares, regardless of what its stages actually do.

#### General

| Option | What it actually does |
|---|---|
| Discard old builds | A retention policy — keep only the last N builds or the last N days. Without it, build history (20.9) grows forever. |
| Do not allow concurrent builds | Serializes runs of *this same job* — a second trigger waits instead of running in parallel. For a job that touches shared state it can't safely share with itself. |
| Do not allow the pipeline to resume if the controller restarts | Jenkins normally tries to resume an in-progress pipeline after a controller restart. Disabling this makes a restart abort the run instead — the right choice when a resumed run risks replaying a non-idempotent step (compute.html 5.6's territory: retries are only safe when the operation tolerates repetition). |
| GitHub project | Just a display link back to the repo's GitHub page — cosmetic, not functional. |
| Pipeline speed/durability override | Trades how often Jenkins persists pipeline state to disk against I/O overhead — safer and slower, or faster and more state lost if the controller crashes mid-run. |
| Preserve stashes from completed builds | A `stash` (files passed between stages/agents) is normally discarded once the build finishes — this keeps it around afterward for inspection. |
| This project is parameterized | The UI equivalent of a Jenkinsfile's `parameters {}` block (20.11) — configured by clicking instead of by code. |
| Throttle builds | Rate-limits how often, or how many concurrently, this job (or a named category of jobs) can run — for protecting a shared resource several different jobs compete for. |

!!! danger "Concurrent-build prevention and throttling solve different problems"

    "Do not allow concurrent builds" only stops *this one job* from overlapping with itself. "Throttle builds" limits a whole category of jobs against each other — useful when five unrelated jobs all hit the same rate-limited API and none of them individually looks like the problem.

#### Triggers

| Trigger | What starts the build |
|---|---|
| Build after other projects are built | Upstream/downstream chaining — this job runs automatically once a named other job finishes. |
| Build periodically | A cron-syntax schedule — the same five-field format as compute.html 5.6's scheduled scaling policies, evaluated in the controller's own timezone. |
| GitHub hook trigger for GITScm polling | The real webhook (20.12) — GitHub pushes an event to Jenkins the moment something happens, no delay. |
| Poll SCM | The older mechanism 20.12 contrasts against webhooks directly — also cron-syntax, but Jenkins checks the repo on a timer instead of being told immediately. |
| Trigger builds remotely | An authenticated URL with a token, callable by an external script or system to start a build without needing full Jenkins API credentials. |

#### Scheduling a pipeline: `triggers { cron(...) }` in the Jenkinsfile itself

"Build periodically" in the table above configures a schedule through the UI — a Jenkinsfile can declare the identical schedule as code instead, in the same `triggers {}` block already used for the GitHub hook (20.12):

```groovy
pipeline {
    agent { label 'agent-one' }
    triggers {
        cron('H 2 * * *')
    }
    stages {
        stage('Nightly check') {
            steps { echo 'Runs once a day, somewhere around 2am' }
        }
    }
}
```

Same reasoning as the danger box just below this one: a schedule written into the Jenkinsfile is checked into git, reviewable, and travels with the branch (20.12's Multibranch Pipeline can even give a feature branch its own, different schedule); a schedule set only through the UI's "Build periodically" checkbox is invisible to anyone reading the repo.

#### Cron syntax, and Jenkins' one real addition to it

Five fields, the same order as a standard crontab:

```
MINUTE  HOUR  DOM  MONTH  DOW
0       2     *    *      *        → 02:00 every day
*/15    *     *    *      *        → every 15 minutes
0       9-17  *    *      MON-FRI  → hourly, 9am-5pm, weekdays only
```

`H` (hash) — Jenkins' own addition, and the one actually worth using
:   `H 2 * * *` looks like "2am," but `H` isn't a fixed value — it's a hash of the job's own name: deterministic (the same job always lands on the same minute every time), but spread across the full range for *different* jobs. Written as `0 2 * * *`, a hundred jobs on one Jenkins instance can all be scheduled for exactly 02:00:00, all firing on the same controller and agents at once. `H 2 * * *` spreads those same hundred jobs across the whole 02:00–02:59 hour instead, without anyone hand-picking a different minute for each one. `H` can also scope a narrower range — `H(0-29) * * * *` picks a consistent minute somewhere in just the first half of every hour.

Timezone
:   Evaluated in the controller's own configured system timezone by default (the "Build periodically" row above already notes this) — override it per-trigger by putting a `TZ=` line first, on its own line inside the same string: `cron('TZ=Asia/Dhaka\nH 2 * * *')`.

#### The part usually actually wanted: check-then-act, not just "run on a timer"

A schedule alone only starts a pipeline — most real scheduled jobs still need to *decide* whether there's anything to actually do once they wake up, rather than unconditionally repeating an action every single time. A nightly Terraform drift check is the clearest example:

```groovy
pipeline {
    agent { label 'agent-infra' }
    triggers { cron('H 2 * * *') }
    stages {
        stage('Check for drift') {
            steps {
                script {
                    sh 'terraform init'
                    def exitCode = sh(script: 'terraform plan -detailed-exitcode', returnStatus: true)
                    if (exitCode == 2) {
                        echo 'Drift detected -- infrastructure no longer matches the .tf files'
                        // notify, or gate a follow-up apply, here
                    } else if (exitCode == 0) {
                        echo 'No drift -- infrastructure matches state exactly'
                    } else {
                        error('terraform plan itself failed')
                    }
                }
            }
        }
    }
}
```

`terraform plan -detailed-exitcode`'s exit codes are exactly this check-then-act signal: `0` means no changes needed, `2` means changes were detected (drift, or a `.tf` file that hasn't been applied yet), `1` means the plan itself errored. The schedule (`triggers { cron(...) }`) is what makes this run every night unattended; the exit-code branch is what makes it *only* act — notify, open a ticket, gate a follow-up `apply` — when there's actually something to act on, instead of sending a "checked, all fine" notification every single night regardless.

!!! success "The same shape as every other conditional gate in this chapter"

    Reacting to `terraform plan`'s exit code here is the identical idea as `when { changeset ... }` on the docker-push pipeline (20.14) or a canary's metrics-check gate ([cicd-delivery.md](cicd-delivery.md)) — a scheduled pipeline still checks a real condition before doing anything consequential; the schedule just decides *when* to check, not *whether* the check passed.

!!! note "`pollSCM` is the same cron syntax, for a narrower, git-specific check"

    `triggers { pollSCM('H/5 * * * *') }` (20.12 contrasts this against webhooks) uses this identical cron string format, but its built-in condition is always "did the repository get new commits since last time" — Jenkins checks the repo on the given schedule and only actually starts a build if something changed. A plain `cron(...)` trigger has no built-in condition at all — it fires every time, on schedule, and it's on the pipeline itself (like the Terraform exit-code check above) to decide whether there's anything worth doing once it does.

#### The script definition itself

Further down the same screen, "Pipeline script" is one of two ways to tell Jenkins what to actually run:

``` groovy
pipeline {
    agent any

    stages {
        stage('Hello') {
            steps {
                echo 'Hello World'
            }
        }
        stage('Create Folder') {
            steps {
                sh "mkdir -p devops"
            }
        }
        stage('Bye') {
            steps {
                echo 'Bye'
            }
        }
    }
}
```

!!! danger "This is the opposite of what 20.10/20.11 recommend"

    "Pipeline script" types the Groovy directly into this one field, saved only in Jenkins' own job configuration — invisible to git history, code review, or branch-per-Jenkinsfile discovery (20.12's Multibranch Pipeline). "Pipeline script from SCM" is the other option on the same dropdown — pointing at a `Jenkinsfile` checked into the repository, which is what every example in 20.10 onward assumes. Fine for a five-minute "does Jenkins work at all" test; the wrong choice for anything meant to last.

Use Groovy Sandbox
:   Checked by default — restricts which Java/Groovy APIs a script can call, since arbitrary unrestricted Groovy can do real damage running on the controller. Unchecking it requires an administrator to manually approve the script before it can run.

Pipeline Syntax (link)
:   A built-in generator that produces correct step syntax by filling out a form, instead of memorizing every step's exact arguments from documentation.

### 20.6 Real Pipeline Walkthrough: Git, Credentials & Docker

Everything from 20.1–20.5 in one real, working pipeline: cloning a private repository with a scoped credential, checking out a specific branch, and building a Docker image from the result. Every failure quoted below actually happened, in that order, on a real agent.

#### What the agent host needs installed first

Neither `git` nor `docker` ships on a base Amazon Linux 2023 AMI — both have to be installed explicitly, in the same `user_data` script that installs Java (20.2/18.10):

``` bash
#!/bin/bash
sudo yum update -y
sudo yum install -y java-21-amazon-corretto git docker
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
```

!!! danger "Package names still don't transfer across distros"

    The same lesson as 20.2's `openjdk-21-jre`: that name is Debian/apt's convention and doesn't exist on Amazon Linux. Docker has the identical trap — `docker.io` is the Debian/Ubuntu apt package; Amazon Linux 2023's `yum`/`dnf` repos just call it `docker`. Running `yum install docker.io` here fails immediately with "No match for argument," the same failure shape as the Java naming mismatch, just one distro-naming gotcha away from a different tool.

`usermod -aG docker ec2-user` adds the agent's user to the group that owns `/var/run/docker.sock` (normally `root:docker`, mode `660`) — without it, every `docker` command fails with `permission denied while trying to connect to the Docker daemon socket`, even though the daemon itself is running fine.

!!! danger "Group membership doesn't apply to an already-running process"

    Linux fixes a process's supplementary groups at the moment it's created — editing `/etc/group` afterward doesn't retroactively update a process that's already running. If the Jenkins agent's `java -jar remoting.jar` process started *before* `usermod -aG docker` ran, that specific process keeps failing with "permission denied" on the docker socket forever, even though a brand-new SSH login to the same box (and even `id ec2-user`) correctly shows `docker` in its group list. The account is fixed; the already-running process isn't. Confirmed here by checking the process's own uptime (`ps -o etime= -p <pid>`) — 48 minutes old, well before the fix.

!!! success "The actual fix: kill the old process, don't just re-run the build"

    On the node's own page (**Manage Jenkins → Nodes → agent-one**), click **Disconnect** first — this is easy to miss, and re-running a build without it just reuses the same stale, already-connected process. Only after it shows offline does **Launch agent** actually start a brand-new `remoting.jar` process, one that reads `/etc/group` fresh and correctly picks up the new membership.

#### Authenticating to a private GitHub repository

Cloning a public repo needs no credential at all — the earlier "No credentials specified" line in a build log is completely normal for those. A private repo fails that same anonymous clone outright, so a credential has to exist in Jenkins before the `git` step can succeed.

1. Generate a GitHub Personal Access Token, scoped narrowly
:   GitHub → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**. Repository access: only the one repo needed. Permissions: **Contents: Read-only** — a clone needs nothing more.

2. Store it in Jenkins' credentials store, never in the pipeline script
:   **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**. Kind: **Username with password**. Username: the GitHub username. Password: the token. ID: a memorable string (`github-pat` below) referenced from the pipeline.

3. Reference it from the `git` step by that ID
:   `credentialsId: 'github-pat'` — Jenkins resolves the actual token at checkout time and masks it out of console logs; the pipeline script itself never contains the secret value (20.9's credentials-store principle applies here directly).

An SSH deploy key is the alternative: generate a keypair, add the *public* half under the repo's **Settings → Deploy keys** (read-only), add the *private* half to Jenkins as an **"SSH Username with private key"** credential, and use a `git@github.com:...` URL instead of HTTPS. More setup, but scoped to exactly one repo rather than an account-wide token — worth it across several private repos.

#### The `git` step: url, credentialsId, branch — and beyond

| Parameter | What it does |
|---|---|
| `url` | The remote to clone — HTTPS or SSH form, matching whichever credential type is in use. |
| `credentialsId` | The Jenkins credentials-store ID to authenticate with. Omitted entirely for a public repo, as the earlier "No credentials specified" log line showed. |
| `branch` | A plain branch name — slashes included, e.g. `holding/ui`, a perfectly normal git branch name — resolved against the remote. Also accepts a tag ref directly, e.g. `refs/tags/v1.2.3`, for building from a specific release point instead of a moving branch. |
| `changelog` / `poll` | Booleans controlling whether this checkout contributes to Jenkins' build-changelog UI and SCM-polling baseline — usually left at their defaults unless a job deliberately checks out more than one repository. |

After checkout, Jenkins exposes what it just cloned as environment variables — `env.GIT_COMMIT` (the full SHA) and `env.GIT_BRANCH` — usable straight in a later stage, e.g. tagging a Docker image by commit instead of only by build number:

``` groovy
sh "docker build -t investor-pro:${env.GIT_COMMIT.take(7)} ."
```

The full commit message isn't exposed as an env var, but a plain `git log` in a `sh` step captures it just as easily, once the repo is checked out:

``` groovy
def msg = sh(script: "git log -1 --pretty=%B", returnStdout: true).trim()
```

#### The pipeline, line by line

The actual working pipeline this section is built from:

``` groovy
pipeline{
    agent {label 'agent-one'}
    stages{
        stage("Code"){
            steps{
                echo "This is cloning the code"
                git credentialsId: 'github-pat', url: 'https://github.com/Fahad-Md-Kamal/investor-pro.git', branch:"holding/ui"
                echo "Code cloned successfully"
            }
        }
        stage("Build"){
            steps{
                echo "This is building the code"
                sh "docker build -t investor-pro:${env.BUILD_NUMBER} -t investor-pro:latest ."
            }
        }
        stage("Test"){
            steps{
                echo "This is testing the code"
            }
        }
        stage("Deploy"){
            steps{
                echo "This is deploying the code"
            }
        }
    }
}
```

`pipeline { ... }`
:   The declarative-syntax root block (20.11) — everything inside it is Jenkins-managed structure, not arbitrary Groovy.

`agent {label 'agent-one'}`
:   Pins this entire pipeline to the one node advertising the label `agent-one` (20.1, 20.3) — every stage below runs on that same machine, in the same workspace.

`stages { ... }`
:   The container for every named phase of the build — purely organizational, holds one or more `stage` blocks.

`stage("Code") { ... }`
:   One named phase, shown as its own box in Jenkins' pipeline visualization. The name is just a label — `"Code"` could as easily be `"Checkout"`.

`steps { ... }`
:   The actual commands run inside a stage — every stage needs exactly one.

`echo "..."`
:   Prints a line to the build's console log — used here purely for readability while watching a run, no functional effect.

`git credentialsId: ..., url: ..., branch: ...`
:   The simplified checkout step (this section, above) — clones `url` at `branch`, authenticating with the named credential.

`sh "..."`
:   Runs a shell command on the agent, in the current stage's workspace — here, the actual `docker build`.

`${env.BUILD_NUMBER}`
:   A Jenkins built-in environment variable — the current job's build number, incrementing every run. Used here as an image tag so every build produces a distinct, traceable image, alongside a floating `latest` tag for convenience.

#### The Docker build itself

`docker build ... .` uses `.` — the workspace root — as its build context, which works because the `git` step above clones directly into the workspace root rather than a subdirectory; the real `Dockerfile` at the repo's top level is found without needing a `-f` path. Two tags in one command (`-t investor-pro:${env.BUILD_NUMBER} -t investor-pro:latest`) apply both at once, from a single build — no need to build twice or run a separate `docker tag`.

!!! success "What actually running this looked like"

    Code stage: clone succeeds, credential accepted, correct branch checked out. Build stage: multi-stage `apt-get`/`uv sync` output streams through exactly as it would locally, image exported and tagged. Test and Deploy stages (still placeholder `echo`s here) run last. `Finished: SUCCESS` — the same pipeline shape 20.11's declarative Jenkinsfile builds on next, just with real steps instead of placeholders.

### 20.7 Hardening the Deploy Stage: Frontend Builds, Dockerfile Gotchas & Cleanup

20.6's pipeline reaches `Finished: SUCCESS` — but a green build is not the same as a working deployment. Everything below is a real gap between the two, found by actually opening the deployed URL rather than trusting the pipeline's own exit code.

#### A stage can only have one `steps` block

``` groovy
stage("Code"){
    steps{ /* clone */ }
    steps{ /* copy .env */ }   // invalid -- a second steps block
}
```

!!! danger ""Expected one steps block, but got 2""

    A declarative `stage` allows exactly one `steps` block. This fails before a single step runs — Jenkins rejects the whole script at validation time, not partway through execution. The fix is just merging both step lists into the one block the stage is allowed to have.

#### Building a frontend on the same agent that's already tight on resources

A `t3.micro` agent (1GB RAM, an 8GB disk already shared with Jenkins itself and every Docker image built) is a genuinely hard place to run `npm install` and `npm run build` — this project hit disk pressure, and separately investigated (and rejected) `nvm` as the way to get Node onto the box at all.

!!! danger "nvm installs Node for the wrong user, in a way Jenkins can't see anyway"

    `user_data` runs as **root**, not `ec2-user` — so `curl ... | bash` followed by `nvm install 24` puts Node under `/root/.nvm`, invisible to the account Jenkins actually builds as. Fixing that user mismatch still wouldn't be enough: nvm works by having an *interactive* shell's `~/.bashrc` source `nvm.sh` and rewrite `PATH` — Jenkins' SSH-launched agent (20.3) and every pipeline `sh` step run a **non-interactive, non-login** shell, which never sources `~/.bashrc`. The same shape of bug as the `docker` group issue below: works fine when you SSH in by hand, silently doesn't apply in the actual automated context. A distro package (NodeSource's `yum`/`dnf` repo) avoids both problems at once — the binaries land on the system `PATH` for every user and every shell type, no sourcing required.

!!! success "The fix that actually held: don't build the frontend on the agent at all"

    Rather than fighting a tiny instance's resources for every build, the frontend gets built once (locally, or wherever's convenient), and the built `dist/` output — `index.html` plus a hashed `assets/` folder, Vite's default output — is committed directly into the repo under `src/webapp/frontend_dist/`. Since the Dockerfile already does `COPY src ./src`, the built assets ride along automatically, with zero Node.js on the agent, zero npm install, zero frontend build step in the pipeline at all. The backend's own path resolution matches this exactly: `FRONTEND_DIST_ROOT = APP_ROOT / "frontend_dist"`, i.e. right next to `app.py` inside `src/webapp/` — the same directory the Docker image already contains.

#### A container that "runs" but never actually starts the app

``` text
STATUS: Restarting (0) 3 seconds ago
COMMAND: "python3"
```

!!! danger "No CMD in the Dockerfile means the base image's default runs instead"

    Exit code `0`, not a crash — the tell. With no `CMD`/`ENTRYPOINT` in the Dockerfile, `docker run` falls back to `python:3.12-slim`'s own default command: a bare `python3` interpreter. Detached (`-d`), its stdin is closed immediately, the REPL hits EOF and exits cleanly, and `--restart unless-stopped` loops that forever. No application code ever runs, which is also why `docker logs` came back completely empty — there was nothing to log. Fix: `CMD ["python3", "main.py"]`, pointed at the repo's actual ASGI entrypoint.

#### Dockerfile CMD vs docker-compose's command

Once a `docker-compose.yml` exists alongside the Dockerfile, its `command:` key fully **overrides** the Dockerfile's `CMD` — it doesn't merge with it. Precedence, highest to lowest: a command passed directly on the CLI, then a compose service's `command:`, then the Dockerfile's own `CMD` as the last-resort fallback for a bare `docker run` (only different if the Dockerfile uses `ENTRYPOINT` instead — then `CMD`/`command:` become arguments *appended to* the entrypoint rather than replacing it).

!!! danger ""It works under docker-compose but not under a bare docker run" is a real, common gap"

    A compose file can quietly fix a problem a bare `docker run` still has — here, `docker-compose.yml` pointed `DATABASE_URL` at `postgres:5432` (the Postgres service's *name*, resolved over compose's own Docker network), while the app's own `.env` still says `@localhost:5432`. Inside any container, `localhost` means that container itself, not a sibling container and not the host. A Jenkins `Deploy` stage doing a bare `docker run` (this project's own pipeline, for simplicity) never gets that compose-level override, so the app starts, tries to reach a database on its own loopback, and fails — a problem invisible until someone actually checks whether the deployed app works, not just whether the pipeline went green.

#### The actual fix: let a Makefile target run docker-compose, not the Jenkinsfile itself

Rather than re-implementing `docker-compose.yml`'s networking logic inside the pipeline, the `Deploy` stage was rewritten to call the project's own `Makefile`:

``` groovy
sh "make start"
```

``` text
# Makefile
start:
	docker compose up -d --build
```

!!! success "This fixes the DATABASE_URL/localhost problem for good"

    `docker compose up` builds the app image *and* starts it alongside Postgres on compose's own network, with compose's own environment override taking effect (`DATABASE_URL: postgresql://...@postgres:5432/...`) — the exact override a bare `docker run` could never see. One Makefile target now matches whatever the project's maintainers already use locally, instead of a second, parallel deployment recipe hand-written inside the Jenkinsfile that can quietly drift from it.

!!! danger "echo "make start" runs nothing — it just prints the words"

    A one-character-category mistake with a completely silent failure mode: writing `echo "make start"` instead of `sh "make start"` prints the literal text `make start` to the console log and does nothing else. The build still reaches `Finished: SUCCESS`, because nothing in an `echo` step can fail — there's no command being run to fail. The tell in the log is structural, not textual: a real shell step shows up as `[Pipeline] sh` followed by a line starting with `+` (the shell echoing what it's about to run); an `echo` step shows only `[Pipeline] echo` and the string itself, with no `+` line anywhere. A green pipeline that changed nothing is a strong sign to check for exactly this.

!!! danger "Yet more tools a base AL2023 AMI doesn't have"

    Running `make start` surfaced two more gaps in the same "assume nothing is preinstalled" pattern as 20.2's Java, this section's `git`/`docker`, and 20.7's Node: `make` itself isn't on the base image (`make: command not found`, fixed with `yum install -y make`), and even once Docker Compose's CLI plugin is installed, `docker compose build` separately requires the **Buildx** plugin — "`compose build requires buildx 0.17.0 or later`" — which is a *different* plugin binary, not bundled with Compose itself. Neither AL2023's `yum` repos nor Docker's own package ship it directly; the fix is downloading the plugin binary from Buildx's GitHub releases into the same `/usr/libexec/docker/cli-plugins/` directory Compose's own plugin lives in. Since Buildx's release asset name embeds its version number (`buildx-v0.37.1.linux-amd64`, not a stable filename), resolving the latest tag via GitHub's API first avoids hand-typing a version number into the script that will eventually go stale.

#### Every build leaves behind a full image, forever, unless something removes it

``` groovy
sh """
    docker image prune -f
    docker images investor-pro --format '{{.Tag}}' \\
        | grep -vE '^(latest|${env.BUILD_NUMBER})\$' \\
        | xargs -r -I {} docker rmi investor-pro:{} || true
"""
```

!!! danger "Disk usage that grows by one full image every single build"

    `docker build -t investor-pro:${env.BUILD_NUMBER} -t investor-pro:latest .` creates a brand-new ~1.3GB image on every run, and nothing removes the previous numbered tag automatically. By build 18, if none of the earlier 17 images had ever been cleaned up, that alone is many times the agent's entire 8GB disk — exactly the kind of accumulation that trips a low-disk-space monitor (or the Free Temp Space false-positive in 20.3) and takes the agent offline, with the actual cause being old, unused images rather than anything about the current build. The snippet above runs right after the new container is already live, so there's no window where the image actually in use gets deleted out from under it — it keeps only `latest` and the build currently deployed, and reclaims everything else, every time.

#### Deploying the wrong branch entirely

!!! danger "A Jenkinsfile pointed at a branch that never got the fix merged into it"

    Every fix above — the Dockerfile `CMD`, the `frontend_dist` restructuring — happened on a feature branch. Pointing the `git` step's `branch:` at `main` instead brought back the *exact same* "bare `python3`, exit 0" crash loop from earlier, because `main`'s own Dockerfile still had no `CMD` at all — the two branches had genuinely diverged (`git merge-base --is-ancestor` confirmed neither contained the other), each carrying real, non-overlapping work. There's no Jenkins-side fix for this — it's a git problem wearing a deployment failure's clothes. `git log --oneline branchA..branchB` shows what one branch has that the other doesn't; merging (not rebasing, once a branch may already be deployed from) brings both sets of changes together before pointing the pipeline back at whichever branch is meant to be the source of truth.

### 20.8 Point-to-Point Deploy: investor-pro, Start to Finish

20.6 and 20.7 are the debugging story — every individual bug, in the order it was actually found. This is the destination: the current, complete pipeline for this project, clone to a fully running, fully-seeded application, with nothing left commented out or half-working. Five stages, each doing exactly one job.

``` groovy
pipeline{
    agent {label 'agent-one'}
    stages{
        stage("Code"){
            steps{
                git credentialsId: 'github-pat', url: 'https://github.com/Fahad-Md-Kamal/investor-pro.git', branch:"main"
                sh "mv .env.example .env"
            }
        }
        stage("Test"){
            steps{
                echo "This is testing the code"
            }
        }
        stage("Deploy"){
            steps{
                sh "make start"
            }
        }
        stage("Setup-Data"){
            steps{
                sh """
                    mkdir -p data/raw
                    unzip -o stock-data.zip -d ./data/raw/amarstock
                """
            }
        }
        stage("Ingest All Data"){
            steps{
                sh "docker compose exec -T app python -m src.ingest_data --source all"
            }
        }
    }
}
```

| Stage | What it does | Why it's built this way |
|---|---|---|
| Code | Clones the repo with a scoped credential (20.6), checks out `main`, and turns the committed `.env.example` into the real `.env` the app and compose both read from. | Every later stage assumes `.env` already exists — nothing else in the pipeline creates it. |
| Test | Still a placeholder. A real test suite would run here, before anything gets deployed — failing fast on broken code beats deploying it and finding out from Setup-Data or Ingest instead. | Ordered before Deploy deliberately, even while empty — the position is part of the design, not just the content. |
| Deploy | `make start` → `docker compose up -d --build` (20.7): builds the app image and starts it alongside Postgres, on compose's own network, with compose's environment override correctly pointing `DATABASE_URL` at the `postgres` service rather than `localhost`. | One Makefile target instead of hand-rolled `docker build`/`docker run` in the Jenkinsfile — the pipeline never re-implements deployment logic the project already maintains for local dev. |
| Setup-Data | Unzips the project's own bundled sample dataset (`stock-data.zip`, committed to the repo — no external download, no credentials needed) onto the agent's workspace. | `-o` forces silent overwrite (20.7's non-interactive-shell lesson) — a reused workspace's stale extracted files would otherwise stall the stage on an unanswerable prompt. |
| Ingest All Data | Runs the actual ingestion *inside* the running `app` container via `docker compose exec`, not on the bare agent host. | The container already has Python, `uv`, and every dependency from `uv sync` baked in at build time — the agent host deliberately has none of that, so ingestion has to run where the environment actually exists. |

!!! note "One quiet dependency between Setup-Data and Ingest All Data"

    `docker-compose.yml`'s `app` service mounts `./data:/app/data` — without that volume, the files **Setup-Data** unzips onto the host workspace would be invisible to the container **Ingest All Data** execs into, since every container has its own isolated filesystem regardless of which host directory the exec'ing shell happens to be in. The two stages only work together because of a line in a file neither one directly touches.

!!! success "What "point-to-point" actually means here"

    Starting from a bare EC2 instance with only `install_apache.sh`'s tools on it (Java, git, Docker, Compose, Buildx, make — 20.6/20.7) and an empty Jenkins workspace, this pipeline alone produces a running FastAPI app, a healthy Postgres database, and a fully populated dataset — no manual SSH step, no console click beyond pressing Build. Every stage above exists because a version without it was tried first and failed in exactly the way 20.6/20.7 describe.

### 20.9 Plugin Hygiene, the Credentials Store & Folder-Level Security

Three separate concerns that all show up under "Manage Jenkins," easy to conflate.

#### Plugin hygiene

Every installed plugin is both an attack surface and a maintenance burden — each one can introduce its own vulnerabilities, and each one needs updating independently. Install only what a pipeline actually needs, keep an inventory of what's installed and why, and pin versions rather than auto-updating blindly (the same reasoning as 15.2's provider version pinning, applied to Jenkins' own plugin ecosystem).

#### The credentials store

Jenkins has a built-in, encrypted credential store (*Manage Jenkins → Credentials*) — AWS keys, SSH keys, tokens are added there once and referenced by ID from a `Jenkinsfile`, never hardcoded into pipeline code:

``` groovy
withCredentials([usernamePassword(credentialsId: 'ecr-creds', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
  sh 'docker login -u $USER -p $PASS ...'
}
```

!!! danger "A credential ID in a Jenkinsfile is not the credential"

    `credentialsId: 'ecr-creds'` is just a lookup key — the actual secret value never appears in the pipeline source, never gets committed to the repo, and Jenkins actively masks it out of build console logs. Anyone who can edit the Jenkinsfile can use the credential, but they can't read its value from the code itself.

#### Choosing a credential type

**Manage Jenkins → Credentials → (a store) → Add Credentials** offers six shapes, not just one generic "secret" — picking the one that actually matches what's being stored, instead of defaulting to whichever type was used last, is what makes the credential usable the way a step actually expects it.

[![Jenkins Add Credentials dialog: Select a type of credential — Username with password ("Commonly used for authentication to services like Git, APIs, or registries"), GitHub App, SSH Username with private key, Secret file, Secret text, Certificate ("Upload a PKCS#12 or PEM encoded certificate and private key")](images/jenkins/credential-types.png)](images/jenkins/credential-types.png){ target="_blank" rel="noopener" }

*The credential-type picker — six distinct shapes, each exposed differently to a pipeline step.*

| Credential type | Use it for | Real-world tradeoff |
|---|---|---|
| Username with password | Any username+token/password pair — git over HTTPS (20.6's `github-pat`), Docker Hub (20.14's `dockerhub-creds`), most registries and REST APIs | The most universally supported type and the simplest to set up; a genuinely long-lived static secret unless the "password" field actually holds a scoped, revocable token rather than a real account password |
| GitHub App | GitHub access shared across many jobs or an entire org, rather than one person's token | Jenkins holds an App ID and a private key, then mints a short-lived, auto-rotating installation token per use — nothing long-lived sits in the credential store at all, and access doesn't vanish when whoever registered it leaves. Costs more to set up once (registering the App, installing it, generating a key) than a PAT generated in a minute |
| SSH Username with private key | Git over SSH, scoped to exactly one repo via a GitHub deploy key (20.6's alternative to a PAT) | No password ever transmitted, and a deploy key can be read-only and repo-scoped; doesn't work on a network that blocks outbound SSH (port 22), and rotation/revocation is manual unless something else automates it |
| Secret file | A secret that's naturally a whole file, not a string — a `kubeconfig`, a cloud service-account JSON key, a license file, a `.pem` | Matches the actual shape of the secret instead of awkwardly pasting file contents into a text field; a consuming step has to read it via a temp file path (`withCredentials([file(...)])`), one more layer of indirection than a plain env var |
| Secret text | A single opaque value with no username — an API key, a webhook token, a Slack token | The simplest possible shape for a one-value secret; forces anything that actually needs more than one field (a username *and* a token) into a single string, which then has to be parsed back apart manually |
| Certificate | Mutual TLS or code-signing — a service that requires a client certificate rather than a bearer token or password | The correct fit exactly when a target genuinely requires certificate-based auth; unnecessary complexity as a stand-in for any of the simpler types above, and this project's own pipelines never need one |

!!! danger "The credential type doesn't enforce what actually goes in the 'password' field"

    "Username with password" works equally well whether the password field holds a real account password or a narrowly-scoped, individually-revocable token — Jenkins has no way to tell the difference, and both look identical once masked in a console log. 20.6's `github-pat` and 20.14's `dockerhub-creds` are both this type, and both are deliberately fine-grained tokens (a repo-scoped GitHub PAT, a Docker Hub access token), not either account's actual login password — precisely so that leaking or rotating one doesn't mean rotating the account's real password, and so the blast radius of a compromised Jenkins credential store is one repo or one registry, not a whole account.

#### Credential providers: the store isn't always Jenkins' own

Every credential covered above (20.6's `github-pat`, 20.14's `dockerhub-creds`) lives in Jenkins' own built-in encrypted store — but that store is just the *default* **credential provider**, not the only one. Jenkins exposes credential lookup as a pluggable extension point, so a plugin can make Jenkins fetch a credential from an external system instead, on demand, at build time — HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, CyberArk Conjur, Google Secret Manager, and Kubernetes Secrets all have a credentials-provider plugin. A `credentialsId:` in a Jenkinsfile looks identical either way — the pipeline code doesn't change, only where Jenkins actually resolves that ID from does.

| Reason to use an external provider instead | Why it matters in a real organization |
|---|---|
| Single source of truth | Most orgs already keep secrets in a company-wide vault used by many systems, not just Jenkins. An external provider means Jenkins reads the same secret everyone else does, instead of a second copy pasted into Jenkins that can quietly drift out of sync. |
| Centralized rotation | Rotate the secret once in Vault/Secrets Manager and every consumer, Jenkins included, picks it up automatically. With Jenkins' own store, someone has to remember to log in and update it by hand every time. |
| Dynamic, short-lived secrets | Vault in particular can issue a database credential valid for just a few minutes, auto-expiring on its own. Jenkins' own store holds a static value indefinitely until someone manually changes it — a leaked value there stays valid until then. |
| Audit trail and access policy | Enterprise secret managers log every read — who, what, when — and enforce fine-grained access policies. Jenkins' own store doesn't give that level of visibility. |
| Compliance | Some frameworks require secrets to live only in one approved, audited vault, not "encrypted at rest inside a CI tool" — however good that encryption actually is. |

!!! danger "Reduced blast radius is the big one, given 20.10's own backup story"

    20.10 already covers backing up `JENKINS_HOME` in full — and `JENKINS_HOME` is exactly where Jenkins' own credential store persists every secret, encrypted, on disk. Anyone who obtains `JENKINS_HOME` plus its master key can decrypt every credential ever added, all at once — the backup itself becomes something that needs the same protection as the secrets it contains. With an external provider, Jenkins only ever holds a short-lived read credential (a Vault token, an IAM role), fetches the real secret at request time, and never writes it to disk at all — compromising the controller, or leaking a `JENKINS_HOME` backup, no longer hands over every secret it's ever used.

!!! success "The right call for this project is still Jenkins' own store"

    A single-person learning setup has no external vault to stand up or maintain, and no second system already depending on the same secrets — Jenkins' built-in store (20.6's `github-pat`, 20.14's `dockerhub-creds`) is the simpler, correct choice here. The tradeoffs above become the deciding factor at real organizational scale — many teams, many services sharing secrets, and a compliance requirement or an incident response plan that actually depends on centralized rotation and audit — not because the built-in store is broken for a project this size.

#### Folder-level security

Folders aren't just organization — they're a permission and credential-scoping boundary. A credential added inside a folder is only visible to jobs inside that same folder, and role-based/matrix security can grant a team full control over their own folder's jobs without touching anyone else's. This is what makes multi-team Jenkins viable on one shared controller instead of needing a separate instance per team.

### 20.10 Backing Up JENKINS_HOME

`JENKINS_HOME` holds everything: every job's configuration, full build history, encrypted credentials, and every installed plugin's binary. Losing it is losing the entire Jenkins instance's identity, not just the compute it happened to run on.

|  | EBS snapshot | ThinBackup (plugin) |
|---|---|---|
| What it captures | The entire volume, byte for byte | Job configs, build records, and credentials specifically — Jenkins-aware |
| Restore unit | The whole volume, as one point in time | Selectable — restore just job configs without touching build history, or vice versa |
| Where it lives | Infra-level (terraform.html 18.10's EBS volume) — same mechanism as any other point-in-time recovery (databases.html 7.2's RDS backups) | Jenkins-level, scheduled from inside the Jenkins UI itself |

!!! danger "An untested backup is a hope, not a backup"

    The same principle from every other backup strategy in this project applies here without modification: a snapshot that's never been restored is unverified. Actually restoring a `JENKINS_HOME` snapshot onto a fresh controller at least once, before it's needed for real, is what turns "we take backups" into "we know recovery actually works."

### 20.11 The Declarative Jenkinsfile

A `Jenkinsfile` is Jenkins' equivalent of a Terraform config — a checked-in file describing a pipeline as code, instead of clicking through the UI to define a job.

``` groovy
pipeline {
  agent { label 'linux' }

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'stg'], description: 'Target environment')
  }

  environment {
    AWS_REGION = 'ap-south-1'
  }

  stages {
    stage('Test') {
      steps { sh 'npm test' }
    }
    stage('Deploy') {
      when { branch 'main' }
      steps { sh "./deploy.sh ${params.ENVIRONMENT}" }
    }
  }

  post {
    failure { echo 'Notify the team -- build failed' }
    always  { cleanWs() }
  }
}
```

`agent`
:   Where this pipeline runs — a label (20.1), a specific Docker image, or `none` if each stage declares its own.

`parameters`
:   Build-time user input — a dropdown, a string field, a checkbox — collected before the pipeline starts, referenced as `params.NAME`.

`environment`
:   Environment variables available to every step in the pipeline (or scoped to just one `stage` if declared inside it instead).

`when`
:   Guards a `stage` — here, the `Deploy` stage only actually runs on the `main` branch, though it's still evaluated (and skipped) on every other branch's run.

`post`
:   Runs after the pipeline finishes, regardless of outcome — `always`, `success`, `failure`, and others let cleanup or notification logic depend on how the run ended, the closest Jenkins equivalent to a `try`/`finally`.

### 20.12 Multibranch Pipelines, Webhooks & Shared Libraries

Three pieces that turn "one Jenkinsfile" into "a real CI setup serving a whole repository."

#### Multibranch pipeline

Instead of one job per branch created by hand, a multibranch pipeline job scans a repository and automatically creates (and destroys) a pipeline run per branch and per pull request — each one running the *same* `Jenkinsfile`, checked into that specific branch, so a feature branch can even modify its own pipeline before merging.

#### Webhooks

Without a webhook, Jenkins has to poll the repository on a timer to notice new commits — slow, and wasteful when nothing's changed. A webhook has GitHub/GitLab push an event to Jenkins the moment a commit or PR happens, triggering the build immediately instead of waiting for the next poll.

#### Shared libraries

A shared library is a separate git repository of reusable Groovy pipeline code (conventionally under `vars/` and `src/`), loaded into any Jenkinsfile that needs it:

``` groovy
@Library('platform-shared-lib') _

pipeline {
  agent { label 'linux' }
  stages {
    stage('Deploy') {
      steps { deployToEcs(service: 'order-service', environment: 'dev') }
    }
  }
}
```

!!! success "The same reasoning as a Terraform module"

    `deployToEcs(...)` above is a function defined once in the shared library and called from every pipeline that needs to deploy to ECS — the exact same motivation as extracting a Terraform module (16.6): once the same handful of steps shows up in a third Jenkinsfile, that's the signal to stop copy-pasting Groovy and put it in one place every pipeline calls instead.

### 20.13 Certified Jenkins Engineer (CJE)

The external validation for Jenkins specifically, the way terraform.html 19.9 covers Terraform's — CloudBees' [Certified Jenkins Engineer (CJE)](https://university.cloudbees.com/certification-guide-and-information) exam, last updated September 2023. Worth knowing before searching further: CloudBees retired a similarly-named *CCJE* (Certified CloudBees Jenkins Engineer) credential back in 2022 — CJE, without the extra "C," is the one still active.

|  |  |
|---|---|
| Format | 60 multiple-choice questions, 90 minutes |
| Passing score | 66% |
| Prerequisites | None formally, though CloudBees recommends real hands-on Jenkins experience first |
| Tests against | Open-source Jenkins core (not CloudBees CI/Operations Center specifically) |

#### The four exam domains

1. **Jenkins Fundamentals** — core CI/CD concepts, jobs and builds, source code management integration, plugins, security (authentication/authorization), the REST API
2. **Jenkins Administration** — installation, distributed builds, controller/agent configuration, credentials, artifact and fingerprint management, notifications
3. **Pipeline (Build Technologies)** — declarative pipeline syntax, stages and steps, multibranch pipelines, shared libraries, promotion strategies, upstream/downstream triggering
4. **Freestyle (Build Technologies)** — the older, UI-configured job type predating Pipeline-as-code — still a real exam section even though this project skips straight to declarative pipelines

!!! danger "Public breakdowns of the exact weighting disagree"

    Unlike terraform.html 19.9's HashiCorp source (a single official, current objectives page), CloudBees doesn't publish one canonical up-to-date percentage breakdown the way HashiCorp does — third-party prep sites list different weightings and even different section names for the same four domains. Treat the domain list above as directionally reliable, but verify specifics against CloudBees' own current study guide before relying on any one source's exact percentages.

!!! success "Where 20.1–20.12 already land"

    Controller/agent architecture (20.1), installation itself (20.2 — literally named in the Administration domain's topic list), connecting a distributed agent (20.3 — "distributed builds, controller/agent configuration" in the Administration domain, almost word for word), job types and Pipeline job configuration (20.4, 20.5), source code management integration and credentials (20.6 — named explicitly in the Fundamentals domain), real-world pipeline/deployment troubleshooting (20.7 — not a named exam topic, but exactly the kind of "why did the green build not actually work" judgment the Pipeline domain expects), a complete real deployment pipeline end to end (20.8 — the shape of pipeline the Pipeline domain's "build technologies" objective actually expects), plugin/credential/folder security (20.9), the declarative Jenkinsfile (20.11), and multibranch/shared libraries (20.12) map directly onto the Administration and Pipeline domains — the two domains carrying the most exam weight in every breakdown found. Freestyle jobs get a mention in 20.4 but no deep-dive yet — worth a dedicated look before sitting this exam, since it's still a full CJE section.

### 20.14 A Different Shape: Push to Docker Hub Instead of Building Where You Deploy

20.6–20.8 build the Docker image and immediately run it, in place, on the same agent that just cloned the code — the image never leaves that one machine. A second, genuinely different pipeline (`jenkins/pipeline/docker-image-push-pipeline.gvy`) builds the image once and pushes it to Docker Hub instead, so *any* machine with Docker and a pull credential can run the exact same, already-tested image — not a machine that also needs git access, GitHub credentials, and the project's own build toolchain.

#### The pipeline

``` groovy
pipeline{
    agent {label 'agent-one'}
    stages{
        stage("Code"){
            steps{
                git credentialsId: 'github-pat', url: 'https://github.com/Fahad-Md-Kamal/investor-pro.git', branch:"main"
                sh "mv .env.example .env"
            }
        }
        stage("Build"){
            when {
                anyOf {
                    changeset "Dockerfile"
                    changeset "src/**"
                    changeset "pyproject.toml"
                    changeset "uv.lock"
                }
            }
            steps{
                sh "docker build -t investor-pro:${env.BUILD_NUMBER} ."
            }
        }
        stage("Push to Dockerhub"){
            when {
                anyOf {
                    changeset "Dockerfile"
                    changeset "src/**"
                    changeset "pyproject.toml"
                    changeset "uv.lock"
                }
            }
            steps{
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                    sh "docker tag investor-pro:${env.BUILD_NUMBER} fahadmdkamal801/investor-pro:${env.BUILD_NUMBER}"
                    sh "docker push fahadmdkamal801/investor-pro:${env.BUILD_NUMBER}"
                }
            }
        }
        stage("Deploy"){
            steps{
                sh "make start"
            }
        }
    }
}
```

Setup-Data and Ingest All Data (20.8) carry over unchanged after this — the registry push only changes how the image *gets to* the Deploy stage, not what happens once the app is running.

| Stage | What's different from 20.8 | Why |
|---|---|---|
| Build | Tags with only `${env.BUILD_NUMBER}` — no floating `:latest`. | `:latest` matters for a local `docker run`/`docker compose` picking the most recent build off the same machine; once an image is pushed under an explicit tag, nothing downstream needs to guess "latest" locally. |
| Push to Dockerhub | New stage — logs into Docker Hub and pushes the just-built image by name. | This is the actual point of the alternate pipeline: after this stage, the image exists independently of the agent that built it. |
| Deploy | Unchanged — `make start` → `docker compose up -d --build`. | In this project's current form, Deploy still *rebuilds* locally rather than pulling the pushed image — the push exists so the image is *available* to pull elsewhere, not because this particular Deploy stage consumes it yet. A registry-consuming deploy would replace `--build` with a plain `docker compose pull && docker compose up -d`, referencing the pushed tag instead of building from source again. |

!!! note "The registry push doesn't (yet) change what Deploy actually runs"

    Right now Build creates a local image, Push sends a copy to Docker Hub, and Deploy still rebuilds from source rather than pulling what was just pushed — so the pushed image isn't actually consumed by this pipeline yet. That's fine as a first step, but the real payoff of this approach — a separate host, or a separate pipeline, pulling the exact tested artifact instead of rebuilding it — only shows up once something downstream actually runs `docker pull fahadmdkamal801/investor-pro:<tag>` instead of building again.

#### The pipeline, step by step

`stage("Code")`
:   Clones the repo with the same scoped `github-pat` credential as 20.6, checks out `main`, and turns the committed `.env.example` into the real `.env` — identical to 20.8's own Code stage.

`stage("Build")`
:   Gated by `when { anyOf { changeset ... } }` (see below) — only runs if the commits this build picked up actually touched `Dockerfile`, `src/**`, `pyproject.toml`, or `uv.lock`. When it does run: `docker build -t investor-pro:${env.BUILD_NUMBER} .` builds the image and tags it with just the Jenkins build number — no `:latest` this time (see the stage-differences table above for why).

`stage("Push to Dockerhub")`
:   Gated by the same `when` condition as Build, so the two stages always agree — Push never runs against an image Build didn't just create. `withCredentials([...])` binds the stored Docker Hub username and password to two masked environment variables, scoped to just this block. Three shell steps run in order inside it: log in (`docker login`, fed the password over stdin so it never shows up in `ps` output or shell history), re-tag the just-built image under the Docker Hub namespace (`fahadmdkamal801/investor-pro:...` — Docker Hub requires the image name prefixed with the account it's being pushed to), then push it.

`stage("Deploy")`
:   `make start` → `docker compose up -d --build`, the same as 20.7/20.8 — rebuilds and (re)starts the app locally. Doesn't yet consume the image that was just pushed (see the note above).

#### Why this is a different shape, not just an extra stage

20.6–20.8's approach ties build and deploy together: whatever machine has the source checked out is also the machine that ends up running the container. That's simple, but it means every deploy target needs git access, GitHub credentials, and the full build toolchain (Docker, Compose, Buildx, `make` — 20.6/20.7's whole list). Pushing to a registry breaks that coupling: build once, on one machine that's allowed to see the source, and let every other machine that needs to run the app pull an already-built, already-tagged image and nothing else. It's the same "build once, deploy the identical artifact everywhere" principle behind an AMI (compute.html) or an immutable Terraform-provisioned resource — a registry just does it for containers instead of instances.

#### `withCredentials` here, vs. the `git` step's own `credentialsId`

Both stages authenticate to something, but through two different mechanisms, worth telling apart on purpose:

| Step | Mechanism | Why |
|---|---|---|
| `git credentialsId: 'github-pat', ...` | Native — the `git` step accepts a `credentialsId` parameter directly, and Jenkins resolves and applies it internally. The token is never exposed as a shell variable. | `git` is a first-class Jenkins step that already knows how to authenticate. |
| `docker login` inside `withCredentials([usernamePassword(...)])` | Generic — `docker login` is a plain shell command, not a Jenkins step, so there's no `credentialsId:` parameter to give it. `withCredentials` binds the stored credential to masked environment variables (`DOCKER_USER`, `DOCKER_PASS`) for just that block, and the `sh` step uses them explicitly. | Only needed when the thing being authenticated is a raw CLI call with no native Jenkins-step integration. |

!!! note "A native alternative exists for Docker specifically"

    The Docker Pipeline plugin provides `docker.withRegistry('https://registry.hub.docker.com', 'dockerhub-creds') { docker.image(...).push() }` — the same "the step handles the credential internally" shape as the `git` step, instead of manually piping a password into `docker login`. Not required — the manual version above works fine — just the same kind of upgrade the `git` step already represents over hand-rolling authentication.

#### Avoiding a rebuild-and-push on every run, even with no code changes

Without a guard, Build and Push run unconditionally every single time the pipeline executes — including a manual re-run where nothing in the repo actually changed since the last one. That's wasted build time, a new ~1.3GB layer set pushed for no reason, and disk pressure on whichever agent runs it (20.7's cleanup problem, made worse).

`when { anyOf { changeset ... } }` — the fix actually applied above
:   A `when` block on a stage can gate it on Jenkins' own SCM changelog for that build — the set of files the commits it just picked up actually touched. `changeset` takes one pattern per call, so checking several paths means one `changeset` line per path inside `anyOf { ... }` — `changeset "Dockerfile"`, `changeset "src/**"`, `changeset "pyproject.toml"`, `changeset "uv.lock"`, any one of which being true runs the stage. A run triggered by a docs-only commit matches none of them and skips Build and Push entirely, no extra state needed to track it. A plain re-run with no new commits at all has an empty changelog, so the same condition skips that too. Both stages repeat the identical `when` block on purpose — Push must never run against an image Build didn't just (re)create, and since both conditions are evaluated against the same build's changelog, they always agree.

Comparing the current commit against the last one successfully pushed — a stricter fit, not yet applied
:   `changeset` answers "did anything change since the last build," which isn't quite "since the last *successful push*." Persisting the pushed commit's SHA somewhere durable (a small file outside the workspace, since the workspace itself can be wiped between builds) and comparing it against `env.GIT_COMMIT` at the start of a run also catches the case a previous run's push actually failed — a `changeset`-only check would stay green on the very next run even though nothing had actually reached Docker Hub yet. Worth adding if a failed push in production actually happens; not needed to get the basic "skip when nothing relevant changed" behavior working.

### 20.15 Locking Down the Controller: the Global Security Page

**Manage Jenkins → Security** (`configureSecurity` in the URL — an older name, "Configure Global Security," still shows up there and in a lot of documentation) is the one screen controlling who can reach Jenkins at all, and what they can do once they're in. Every pipeline, credential, and agent covered so far in this chapter assumes a controller that's actually locked down — an open one turns every trick in 20.6–20.14 into something an anonymous visitor could also do.

[![Jenkins Manage Jenkins Security page: Authentication (Security Realm: Jenkins' own user database, Authorization: Logged-in users can do anything), Markup Formatter, Agents (TCP port for inbound agents: Disable), CSRF Protection (Default Crumb Issuer), Git plugin notifyCommit access tokens, Prism syntax highlighting, Git Hooks, Hidden security warnings, API Token, Content Security Policy, Git Host Key Verification Configuration, Sandbox Configuration](images/jenkins/jenkins-Security-management.png)](images/jenkins/jenkins-Security-management.png){ target="_blank" rel="noopener" }

*The full Security page on a fresh controller — mostly still at Jenkins' own defaults. Click the screenshot to open it full-size in a new tab (it's a tall, full-page capture, so this page shrinks it to fit — every field is covered individually below regardless).*

#### Authentication: who can even log in

Security Realm
:   Where Jenkins checks a username/password against. "Jenkins' own user database" (shown above) stores accounts inside Jenkins itself — fine for a single small team or a learning setup like this one. A real organization more often points this at LDAP, an existing SSO provider (SAML/OIDC via plugin), or GitHub OAuth — one fewer separate password to manage, and accounts disappear from Jenkins automatically the moment someone leaves the identity provider, instead of lingering as a Jenkins-local account nobody remembers to delete.

Allow users to sign up
:   Only relevant with "Jenkins' own user database" — lets anyone who can reach the login page create their own account, unauthenticated. Off by default, and worth leaving off for anything beyond a personal instance: combined with a permissive Authorization setting below, self-registration can mean "anyone on the internet who finds this URL can grant themselves an account."

#### Authorization: what a logged-in user can do

Authorization
:   "Logged-in users can do anything" (the default shown above) means exactly what it says — every authenticated account is a full administrator, with no distinction between "runs builds" and "can rewrite security settings, read every credential's metadata, or delete other people's jobs." Fine for one person's own instance; the wrong choice the moment a second person gets an account. "Matrix-based security" or the Role-based Authorization Strategy plugin replace it with per-user or per-role permission grids — the same folder-level scoping 20.9 already covers, but enforced globally, before folders even come into it.

Allow anonymous read access
:   Lets anyone reach Jenkins' UI and REST API without logging in at all, read-only. Harmless for an internal dashboard nobody minds being visible; a real exposure if the controller is reachable from the public internet — job configuration, build console logs (which can leak environment details even with credential masking), and the list of installed plugins and their versions are all useful reconnaissance for an attacker, handed over with zero authentication.

!!! danger "The real-world failure mode: sign-up plus full-admin-by-default, left on past a demo"

    "Allow users to sign up" and "Logged-in users can do anything" are both convenient for a five-minute local demo — exactly this project's own setup — and both look harmless since they're one click to reverse later. The actual incidents this combination causes in the wild happen when a controller stood up quickly for a demo or a hackathon stays reachable afterward with the defaults untouched: anyone who finds the URL registers their own account and is instantly a full administrator, credentials store included. The fix isn't a special "hardening mode" to remember later — it's simply not leaving demo defaults on a controller anyone outside the original small circle can reach.

#### CSRF Protection

Crumb Issuer
:   Jenkins' defense against Cross-Site Request Forgery — a "crumb" (a per-session token) has to be included on every state-changing request, so a malicious page a logged-in user happens to have open elsewhere can't silently trigger a build or change a setting just by getting their browser to send a request. "Default Crumb Issuer" is the safe default; some older third-party tooling recommends disabling this to simplify scripted API calls, which is exactly the tradeoff to avoid — a scripted client can fetch and send a crumb like anything else, and disabling this reopens the exact attack the setting exists to prevent.

#### Agents: TCP port for inbound agents

Fixed / Random / Disable
:   Only relevant if any agent connects *inbound* to the controller (20.1's Inbound/JNLP agent type — the fix for an agent behind NAT the controller can't reach outbound). This project's own agent (20.3, 20.6) connects via the controller-initiated SSH method instead, which needs no open inbound agent port at all — so "Disable" here (the setting shown above) is correct for this exact setup, and removes one more open port from the controller's attack surface. Switching to an inbound/JNLP agent later would mean coming back to this exact setting first, or the new agent has nothing to connect to.

#### Git Hooks

Allow on Controller / Allow on Agents
:   Both off by default. A git hook is a script git's own tooling runs automatically on certain repository events — allowing one to run **on the controller** means arbitrary script execution on the one process 20.1's very first danger box says never to run arbitrary code on. It's the same principle as "never build directly on the controller," just reachable through a different door than a pipeline step; leaving both unchecked unless a specific, trusted workflow genuinely needs one is the safer default.

#### Sandbox Configuration

Force the use of the sandbox globally in the system
:   20.5 already covers the per-script "Use Groovy Sandbox" checkbox, checked by default on any one Pipeline job. This setting removes the choice entirely, instance-wide — no job's script can ever run outside the sandbox, regardless of what an individual job's own configuration says. Worth turning on the moment more than one person can author pipeline scripts on the same controller, since it closes off "someone unchecks the sandbox box on their own job" as a way around the restriction.

#### The rest of the page, briefly

| Section | What it's for |
|---|---|
| Markup Formatter | Controls how job/build descriptions render — "Plain text" (safe default, escapes HTML) vs. "Safe HTML," which allows a limited, sanitized HTML subset for richer formatting at a small added complexity cost. |
| Git plugin notifyCommit access tokens | Scoped tokens specifically for the Git plugin's `notifyCommit` webhook URL (20.12), separate from a full API token — lets a webhook trigger builds without handing out a broader credential. |
| Prism syntax highlighting | Restricts which on-agent directories the source-code-viewer's syntax highlighter is allowed to read from outside a job's own workspace — closes off a path-traversal-style read of arbitrary files on the agent. |
| Hidden security warnings | Lets an administrator dismiss specific known-issue warnings (e.g. about an outdated plugin) after consciously deciding the risk is accepted, rather than a warning banner persisting forever. |
| API Token | Governs *legacy* API tokens specifically — modern Jenkins issues a distinct, individually revocable token per named purpose instead. Both legacy options here are marked "Not recommended" for exactly that reason: one shared token per user is harder to rotate or scope than several purpose-specific ones. |
| Content Security Policy | A browser-enforced header restricting what the Jenkins UI itself is allowed to load or execute — defends against a compromised or malicious plugin's UI content doing something the rest of the page shouldn't allow. Disabled by default because some older plugins' UIs aren't CSP-compatible yet. |
| Git Host Key Verification Configuration | Controls how Jenkins verifies a remote git server's SSH host key before trusting it — "Known hosts file" (shown above) matches the same `~/.ssh/known_hosts` trust model any manual `ssh`/`git` client uses, rather than blindly accepting whatever key a server presents. |

!!! success "Verifying this page's settings are actually taking effect"

    No separate "test" button exists — the way to confirm Authorization is actually enforced is to log in (or check anonymously, in a private browser window) as a lower-privileged account and confirm the action that should be blocked actually is, the same "don't just trust the config, check the real behavior" principle 20.7 applies to a deployed application. A CSRF crumb rejection shows up as a `403` with `No valid crumb was included in the request` in the response body if a scripted client forgets to fetch and send one — a good sign the protection is live, not a bug to work around by disabling it.

### 20.16 A Multi-Agent, Multi-Pipeline Deployment: Infra, Build, and Deploy as Three Separate Jobs

Every pipeline shown so far in this chapter runs start to finish on one agent. A real platform more often splits the work across three genuinely separate Jenkins *jobs* — each on its own labeled agent, sometimes literally a different machine — triggered off each other rather than living as stages in one Jenkinsfile. This is [cicd-delivery.md](cicd-delivery.md)'s "which comes after which" question again, but drawn at the level of physical agents and separate credential scopes instead of just pipeline stages.

#### Why three separate jobs on three separate agents, not one

- **Least privilege, taken further than 20.9's credential scoping** — a build agent never needs AWS deploy permissions; a deploy agent never needs a GitHub push token or Docker Hub push credentials, only pull access and whatever AWS role actually performs the deployment. A compromised build agent (a malicious dependency executing code during `docker build`, say) simply has no path to production at all, because it holds no AWS credentials to reach it with.
- **Independent cadence** — infrastructure changes rarely; the app deploys on every merge. A dedicated infra job, with its own trigger and its own approval gate, doesn't get dragged along on every app-only commit — [cicd-delivery.md](cicd-delivery.md)'s "One pipeline or two" section covers the same tradeoff one level up, as guarded stages in one pipeline rather than fully separate jobs.
- **Toolchain isolation** — the build agent needs Docker and Buildx (20.6/20.7's install list); the deploy agent needs the AWS CLI and IAM permissions for ECS/CodeDeploy/ELB; the infra agent needs Terraform. None of the three needs what the other two have installed, so none of the three's attack surface includes tools it never uses.

#### The three pipelines

**1. Infra pipeline — `agent-infra`**

```groovy
pipeline {
    agent { label 'agent-infra' }
    stages {
        stage('Terraform') {
            steps {
                sh 'terraform init'
                sh 'terraform plan -out=tfplan'
                input message: 'Apply this plan?'
                sh 'terraform apply -auto-approve tfplan'
            }
        }
    }
}
```

Triggered manually, or by a webhook scoped to `.tf` file changes ([cicd-delivery.md](cicd-delivery.md)'s `changeset` guard) — not by every commit to the application repo.

**2. Build pipeline — `agent-build`**

```groovy
pipeline {
    agent { label 'agent-build' }
    stages {
        stage('Code') {
            steps { git credentialsId: 'github-pat', url: 'https://github.com/Fahad-Md-Kamal/investor-pro.git', branch: 'main' }
        }
        stage('Build & Push') {
            steps {
                sh "docker build -t fahadmdkamal801/investor-pro:${env.GIT_COMMIT.take(7)} ."
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                    sh "docker push fahadmdkamal801/investor-pro:${env.GIT_COMMIT.take(7)}"
                }
            }
        }
        stage('Trigger deploy') {
            steps {
                build job: 'deploy-pipeline',
                      parameters: [
                          string(name: 'IMAGE_TAG', value: env.GIT_COMMIT.take(7)),
                          string(name: 'STRATEGY', value: 'canary')
                      ],
                      wait: false
            }
        }
    }
}
```

Triggered by a GitHub webhook (20.12) on every push to `main`. Its last stage is the actual handoff to a different machine — `build job:` starts an entirely separate Jenkins job, on a different agent, and passes it exactly which image tag to deploy. `wait: false` means this pipeline reports success the moment it has kicked off the deploy job, rather than sitting there watching someone else's job run.

**3. Deploy pipeline — `agent-deploy`**

```groovy
pipeline {
    agent { label 'agent-deploy' }
    parameters {
        string(name: 'IMAGE_TAG', defaultValue: '')
        choice(name: 'STRATEGY', choices: ['blue-green', 'canary', 'shadow'])
    }
    stages {
        stage('Pull image') {
            steps { sh "docker pull fahadmdkamal801/investor-pro:${params.IMAGE_TAG}" }
        }
        stage('Blue/green') {
            when { expression { params.STRATEGY == 'blue-green' } }
            steps { echo "Runs cicd-delivery.md's CodeDeploy stage, IMAGE_TAG substituted in" }
        }
        stage('Canary') {
            when { expression { params.STRATEGY == 'canary' } }
            steps { echo "Runs cicd-delivery.md's weighted-ALB ramp loop" }
        }
        stage('Shadow') {
            when { expression { params.STRATEGY == 'shadow' } }
            steps { echo "Deploys v2 behind its own target group at 0% live weight" }
        }
    }
}
```

This pipeline never touches source code or a Dockerfile at all — it only ever pulls an already-built, already-tagged image and applies whichever rollout strategy the `STRATEGY` parameter selects, using the exact mechanics [cicd-delivery.md](cicd-delivery.md)'s "Blue/green and canary, driven from the pipeline" section already covers.

#### Shadow: the one strategy with no ALB-weight equivalent

Blue/green and canary both work by adjusting how much production traffic reaches v2 — a target-group swap or a weight change. Shadow (principles.md 2.1.5) is structurally different: v1 keeps serving 100% of real traffic and real responses the whole time, while a *copy* of each request is additionally sent to v2, whose response gets thrown away. Jenkins' role shrinks accordingly here — it deploys v2 behind its own target group at zero live weight, exactly like the first step of a canary, but the actual request duplication is handled by something outside the ALB entirely (a service mesh route, a Lambda, or the application layer itself), since a plain ALB has no "send a copy of this request elsewhere and discard the response" mode. The deploy pipeline's job stops at "v2 is running and reachable" — wiring up the mirroring itself is a separate, one-time infrastructure task, not something repeated on every deploy.

#### Who needs which credential — and, just as importantly, who doesn't

| Agent | Needs | Never needs |
|---|---|---|
| `agent-infra` | AWS credentials scoped to Terraform's own IAM role, access to the Terraform state backend | A GitHub push token, Docker Hub credentials |
| `agent-build` | `github-pat` (clone), `dockerhub-creds` (push) | Any AWS deploy permission at all |
| `agent-deploy` | Docker Hub pull credentials (if the registry is private), AWS credentials scoped to ECS/CodeDeploy/ELB actions | GitHub credentials, Docker Hub push credentials |

#### The full picture: three machines, one release

```mermaid
flowchart LR
    subgraph InfraAgent["agent-infra: Terraform"]
        TFPlan[terraform plan] --> TFApprove[Manual approval] --> TFApply[terraform apply]
    end

    subgraph BuildAgent["agent-build: Docker"]
        GH[GitHub webhook: push to main] --> Clone[git clone]
        Clone --> DockerBuild[docker build, tag by commit]
        DockerBuild --> Push[docker push to Docker Hub]
        Push -->|"build job: deploy-pipeline"| Trigger[Trigger deploy-pipeline]
    end

    subgraph DeployAgent["agent-deploy: AWS CLI"]
        Trigger --> Pull[docker pull IMAGE_TAG]
        Pull --> Strategy{STRATEGY param}
        Strategy -->|blue-green| BG[CodeDeploy: atomic swap]
        Strategy -->|canary| Canary[Weighted ALB ramp: 5% then 25% then 100%]
        Strategy -->|shadow| Shadow[Deploy v2 at 0% live weight]
    end

    TFApply -.->|infra must already exist, not per-release| Pull
```

!!! danger "This is also what limits the damage a compromised build agent can do"

    Because `agent-build` holds `github-pat` and `dockerhub-creds` but zero AWS credentials, the worst outcome of it being compromised is a malicious image getting pushed to Docker Hub — it has no way to reach production directly. That malicious image still has to pass through `agent-deploy`'s own rollout strategy — a canary's metrics-comparison gate, or a blue/green deployment's CloudWatch-alarm-triggered rollback — before it could actually harm real traffic. Splitting the agents doesn't just organize the work; it puts a real gate between "an attacker can push an image" and "an attacker's code runs in production."

!!! success "This is what a genuinely complex, real pipeline looks like"

    Not one Jenkinsfile with twenty stages, but several small, single-purpose pipelines, each on a differently-scoped agent, connected by explicit `build job:` triggers instead of implicit sequential stages — the same "which comes after which" question [cicd-delivery.md](cicd-delivery.md)'s end-to-end diagram answers at the level of logical steps, now answered at the level of which machine does which part, and what each one is and isn't trusted with.
