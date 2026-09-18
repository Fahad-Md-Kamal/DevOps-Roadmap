---
title: Terraform
---

# Terraform: Infrastructure as Code

## 15 From Clicks to Code

Everything in Weeks 1–3 was built by clicking in the AWS console or typing one-off `aws` CLI commands. Neither leaves behind a record of the *intended* state of the infrastructure — only whatever state it happens to be in right now. Terraform's job is to make that intended state a file you can read, diff, review and re-apply.

### 15.1 What Terraform Is, and Why

Terraform is an Infrastructure-as-Code (IaC) tool: you describe the infrastructure you want in text files, and Terraform figures out which API calls turn what currently exists into that. This is a **declarative** model — you say *what* should exist ("one t3.micro instance, this security group attached"), not *how* to get there. Compare that to the CLI work from Weeks 1–3, which was **imperative** — each `aws ec2 run-instances` command was a step, and nothing recorded that the step had happened except the resource itself.

|  | Console / CLI (Weeks 1–3) | Terraform |
|---|---|---|
| What you write | A sequence of clicks or commands to run once | A description of the end state, applied repeatedly |
| Record of intent | None — only whatever exists right now | The `.tf` files, committed to git |
| Re-running it | Re-clicking or re-running risks creating duplicates | Re-applying an unchanged config does nothing (idempotent) |
| Review before change | Not possible — the change already happened | `terraform plan` shows the change before it happens |

!!! note "Idempotent"

    Running the same Terraform config twice in a row with nothing changed produces "no changes" the second time — it doesn't create a second copy of anything. This is the property that makes it safe to re-run in CI on every commit, unlike re-running a one-off `aws` command by hand.

Terraform itself is cloud-agnostic — the same tool manages AWS, GitHub, Datadog, or a Kubernetes cluster. What connects it to a specific system is a **provider** (covered next): a plugin that translates Terraform's generic "create this resource" into that system's actual API calls.

### 15.2 Install & Provider Configuration

``` bash
# Install (Linux, via HashiCorp's apt repo)
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

terraform version
```

Every Terraform project starts by declaring which providers it needs, and pinning their versions — the same principle as pinning a package version in `requirements.txt`, for the same reason: an unpinned provider can ship a breaking change and your next `plan` behaves differently with no line changed in your own code.

``` hcl
# versions.tf
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"   # any 5.x, never 6.x
    }
  }
}

provider "aws" {
  region  = "ap-south-1"
  profile = "fahad"
}
```

!!! danger "Unpinned = unreproducible"

    Skip `required_providers` and Terraform silently installs whatever the latest provider version is the first time anyone runs `init`. Two engineers running `init` a week apart can end up on two different AWS provider versions, applying the exact same `.tf` files with different results.

#### A shorter command, if you want one

`terraform` gets typed dozens of times an hour — a shell alias shortens it to two letters. This is a shell feature, not a Terraform one, so it goes in your shell's own config file, not anywhere in this project.

``` bash
# zsh (~/.zshrc) or bash (~/.bashrc) -- same syntax either way
echo "alias tf='terraform'" >> ~/.zshrc
source ~/.zshrc   # reload the current shell so the new alias takes effect

tf plan
tf apply
tf state list
```

!!! note "Where it lives matters"

    An alias defined only by typing it at the prompt disappears the moment that terminal closes. Appending it to `~/.zshrc`/`~/.bashrc` makes it permanent — that file re-runs every time a new interactive shell starts, which is also why a fresh terminal always picks up an edit without needing `source` at all.

#### Widening the constraint later needs -upgrade

Bump `version = "~> 5.0"` to `"~> 6.0"` after `init` has already run once, and a plain `terraform init` fails instead of picking up the new version:

``` text
│ Error: Failed to query available provider packages
│
│ Could not retrieve the list of available versions for provider hashicorp/aws:
│ locked provider registry.terraform.io/hashicorp/aws 5.100.0 does not match
│ configured version constraint ~> 6.0; must use terraform init -upgrade to
│ allow selection of new versions
```

``` bash
terraform init -upgrade
```

!!! note "Why plain init can't fix this on its own"

    `.terraform.lock.hcl` records the exact provider version everyone on the project is currently using — that's the whole point of a lock file (same reason a `package-lock.json` exists). A bare `init` only *installs* whatever the lock file already says; it deliberately never widens a lock to satisfy a new constraint on its own, since silently upgrading everyone's provider version on a routine `init` is exactly the unreproducible behavior the lock file exists to prevent. `-upgrade` is the explicit, opt-in step that re-resolves the constraint and rewrites the lock file — commit that rewritten lock file so the rest of the team gets the same resolved version.

!!! danger "A stray env var beats the profile every time"

    A real `plan` once failed with `InvalidClientTokenId: The security token included in the request is invalid` — even though `aws sts get-caller-identity --profile fahad` worked fine from a different terminal, same machine, same credentials file. Cause: an `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` left exported earlier in that specific shell session, from something typed by hand. Both the AWS CLI and the Terraform AWS provider check environment variables *before* the profile in `~/.aws/credentials` — a stale exported key silently overrides `profile = "fahad"` in every command run in that terminal, with no warning that it's happening. `env | grep AWS` is the first thing to check when a credential error doesn't match what `~/.aws/credentials` actually contains.

### 15.3 HCL Basics: Resources & Data Sources

Terraform's config language is HCL. Everything is a named block: a **type**, a **local name** you choose, and a body of arguments.

#### If you already know a programming language

HCL isn't object-oriented, but the shapes rhyme closely enough that mapping onto OOP terms you already know is a legitimate shortcut — as long as you also clock where the mapping breaks down.

| HCL | OOP equivalent |
|---|---|
| A provider (`hashicorp/aws`) | An imported library/SDK — brings a vocabulary of pre-built "classes" into scope, the way `import boto3` brings AWS's API surface into a Python script |
| A resource/data **type** (`aws_instance`, `aws_ami`) | A class — a fixed blueprint of what arguments and attributes this kind of thing has. You never define one yourself; the provider plugin ships it, versioned (15.2) |
| `resource "aws_instance" "app" { ami = ... }` | Instantiating an object: `app = aws_instance(ami=...)`. The local name (`"app"`) is the variable you're assigning that instance to |
| A `data` block | Calling a read-only getter/query function — not constructing something new, just fetching an existing object's attributes into a reference you can use |
| `aws_instance.app.public_ip` | Dot-notation property access on an object instance — exactly like `my_object.public_ip` |
| A `variable` block | A typed function parameter, complete with a default value and validation — closer to a TypeScript-style typed parameter than an untyped one |
| A `locals` block | A local constant computed once — like `const` in JS or `final` in Java: read-only, can't be overridden from outside |
| An `output` block | A `return` statement — hands a value back to whoever called this config: a human at the CLI for a root module, or the parent config for a child module |
| A `module` call | Calling a function with named arguments (its `variable`s) that hands back named return values (its `output`s) — see 16.4 for designing that interface |

!!! danger "Where the analogy breaks"

    You can't subclass `aws_instance`, add a method to it, or define your own resource types — the "classes" here are closed, fixed by whatever the provider version ships (15.2). And critically, HCL isn't executed top-to-bottom like a script: block order in the file is irrelevant. Terraform reads the references between blocks (see the dependency-order note further down this section) and builds a dependency graph, then executes in whatever order that graph requires — closer to how a spreadsheet evaluates formulas by their cell references than to a program running line by line.

!!! note "Typed, but not general-purpose"

    `variable` blocks are genuinely strictly typed (`string`, `number`, `bool`, `list(...)`, `map(...)`, `object({...})`) with no implicit coercion between incompatible types, and support the same kind of input validation you'd write at a typed function's boundary (16.4). What HCL doesn't have is general-purpose control flow — no user-defined classes, no arbitrary loops, no if/else statements outside of a handful of expression-level substitutes (a ternary, `for` expressions, `dynamic` blocks). It's a declarative configuration language with a real type system bolted on, not a programming language you'd write an algorithm in.

``` hcl
resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

`resource` means "create and manage this" — Terraform will create it, and destroy it if you remove the block. `data` means "look this up, don't manage it" — for something that already exists and you just need to reference (an existing AMI, an existing VPC someone else created).

#### What you can set vs what Terraform tells you afterward

An `aws_instance` plan shows 40+ fields, but only a handful are ones you control — the rest are marked `(known after apply)` because AWS assigns them at creation time and no config value could ever have set them.

``` text
  + resource "aws_instance" "app_server" {
      + ami                          = "ami-0333333333333333"   # you set this
      + instance_type                = "t3.micro"                # you set this
      + arn                          = (known after apply)        # AWS assigns this
      + id                           = (known after apply)        # AWS assigns this
      + key_name                     = (known after apply)        # settable, just unset
      + public_ip                    = (known after apply)        # AWS assigns this
      + subnet_id                    = (known after apply)        # settable, just unset
      + vpc_security_group_ids       = (known after apply)        # settable, just unset
    }
```

`(known after apply)` covers two different situations that look identical in a plan: an argument you simply didn't set (like `key_name` or `subnet_id` above — add it and it stops being unknown), and a true output that no config value could ever populate (like `arn` or `id` — those only exist once AWS creates the real object).

| Category | Examples on `aws_instance` |
|---|---|
| Set, and showing a real value | `ami`, `instance_type`, `tags` |
| Optional, unset — add these to customise | `key_name`, `subnet_id`, `vpc_security_group_ids`, `associate_public_ip_address`, `availability_zone`, `user_data`, `monitoring`, `root_block_device`, `metadata_options`, `iam_instance_profile` |
| Pure output — never settable, at all | `arn`, `id`, `instance_state`, `private_dns`, `public_dns`, `primary_network_interface_id`, `password_data` |

!!! success "The registry docs tell you which is which"

    Every resource page on the [Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) splits into an "Argument Reference" section (settable — everything in the second row above) and an "Attributes Reference" section (read-only — the third row). If something's listed only under Attributes, no amount of config will ever set it directly; it's always read back via a reference like `aws_instance.app_server.public_ip`, the same dot-notation used for `data.aws_ami.ubuntu.id` below.

``` hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id   # reference: type.name.attribute
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web.id]
}
```

#### The data block, reserved keywords vs names you chose

`data`
:   Reserved keyword — "look this up, don't create or manage it." The opposite of `resource`.

`"aws_ami"`
:   The data source's **type**. Fixed, defined by the AWS provider — this is the provider's built-in "look up an AMI" query, not something you name yourself.

`"ubuntu"`
:   A local name **you invented**. Purely a label so the rest of your config can reference this lookup (`data.aws_ami.ubuntu.id` above). Rename it to `"my_ami"` and nothing breaks except that one reference.

`most_recent`
:   A fixed argument from the `aws_ami` schema, not custom. When the filters below match more than one AMI, take the newest instead of erroring on ambiguity.

`filter { name = "name" ... }`
:   `filter` is a repeatable nested block — stack several and all must match (AND logic). Inside it, `name` is a fixed key that says *which AMI field* you're filtering on; confusingly, its value here is also the literal string `"name"`, meaning "filter on the AMI's own Name field" (as opposed to architecture, owner-alias, etc.) — the key and the value are unrelated, they just happen to use the same word.

`values`
:   Fixed argument, always a list even for one item. Supports `*` wildcards — the trailing `*` here exists because the real AMI name ends in a build timestamp that changes with every release.

`owners`
:   Fixed top-level argument, restricts results to AMIs published by this specific AWS account. `099720109477` is Canonical's real, publicly documented account ID for official Ubuntu AMIs — not a secret, the same ID AWS's own docs use.

!!! danger "Why owners isn't optional"

    Without it, the name-pattern filter alone could match an AMI from *any* account that happens to use a similar name — including a malicious lookalike published to look official. Pinning `owners` is what makes this query trustworthy, not just convenient.

!!! note "This runs as a live query"

    The whole `data` block executes against the real AWS API at `plan`/`apply` time — it returns whatever AMI currently matches, so `aws_instance.app` always gets the latest Ubuntu AMI instead of a hardcoded ID that goes stale next month.

!!! note "This is where dependency order comes from"

    `aws_instance.app` references `aws_security_group.web.id` and `data.aws_ami.ubuntu.id` — Terraform reads these references to build its dependency graph automatically. It knows to create the security group before the instance without you writing anything that says "do this first." This is exactly why explicit `depends_on` (see 16.3) is a last resort, not a first instinct — most ordering should come from references like these.

#### Heredoc strings — for a multi-line value like user_data

Writing a multi-line script inline as a normal quoted string means escaping every newline. A heredoc avoids that — everything between the opening marker and its matching closing line is taken literally, newlines included:

``` hcl
resource "aws_instance" "app" {
  # ...
  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y apache2
  EOF
}
```

!!! danger "No space between <<- and the marker"

    `<<- EOF` (with a space) fails to parse at all — `Invalid expression: Expected the start of an expression, but found an invalid expression token` — because `<<-` and the marker name have to be written as one unbroken token, `<<-EOF`. With the space, Terraform doesn't recognize it as a heredoc opener, and everything that follows (including the actual script content) gets misparsed as HCL rather than treated as string content.

!!! note "Why the hyphen"

    `<<-EOF` (with the hyphen) strips the leading whitespace common to every line, which is what lets the closing `EOF` sit indented to match the surrounding code instead of needing to start at column 0, the way a plain `<<EOF` would require.

### 15.4 The Workflow: init, plan, apply, destroy

``` bash
# 1. Download providers/modules this config needs (run once per checkout, or after adding one)
terraform init

# 2. Show what WOULD change, without changing anything
terraform plan

# 3. Actually make the change (re-shows the plan, asks for confirmation)
terraform apply

# 4. Tear everything this config manages back down
terraform destroy
```

`init`
:   Downloads the provider plugins declared in `versions.tf` and any modules referenced by `source`, and sets up the backend that stores state (Day 17). Safe to re-run any time — it doesn't touch real infrastructure.

`plan`
:   Compares your `.tf` files against Terraform's record of what it last created (the state file) and against the real infrastructure, and prints exactly what it would add, change, or destroy. Nothing is touched. This is the step you never skip.

`apply`
:   Runs the same comparison as `plan`, shows it to you, and — after you type `yes` — makes the real API calls.

`destroy`
:   The inverse of `apply`: deletes everything this config currently manages. Same confirmation prompt, same real API calls, in reverse.

!!! success "Never apply without reading the plan"

    The habit that matters more than any command: read what `plan` says before typing `yes` at `apply`. A one-line variable change can produce a plan that destroys and recreates a database if it touches a value that forces replacement — the diff is the only place that would be visible before it happens.

### 15.5 Reading a Plan Diff Line by Line

``` text
Terraform will perform the following actions:

  # aws_instance.app will be updated in-place
  ~ resource "aws_instance" "app" {
        id            = "i-0aaa1111aaaa11111"
      ~ instance_type = "t3.micro" -> "t3.small"
        # (28 unchanged attributes hidden)
    }

  # aws_launch_template.app must be replaced
-/+ resource "aws_launch_template" "app" {
      ~ id          = "lt-0bbb2222bbbb22222" -> (known after apply)
      ~ image_id    = "ami-0111111111111111" -> "ami-0222222222222222" # forces replacement
        name_prefix = "app-"
    }

Plan: 1 to add, 1 to change, 1 to destroy.
```

`~` update in-place
:   The resource stays, but an attribute changes on the live object — no downtime for something like an EC2 instance's `instance_type` (it does still require a stop/start under the hood for that particular attribute, which Terraform will also tell you about).

`-/+` destroy and re-create (replacement)
:   The changed attribute can't be updated on the existing object at all — AWS's API has no "update" call for it — so Terraform must delete the old one and create a new one. The line `# forces replacement` tells you exactly which attribute triggered this.

`+` / `-` alone
:   A resource being newly created, or a resource being removed because its block was deleted from the config.

"Plan: X to add, Y to change, Z to destroy"
:   The summary line at the bottom. Read the detail above it first — "1 to change" reads harmless right up until you notice it's the production database's launch template being replaced, not updated.

!!! danger "The line to actually watch for"

    `# forces replacement` is the single most consequential phrase in any plan output. For anything stateful (a database, an EBS volume with data on it), a forced replacement means the resource is destroyed and a brand-new empty one created in its place — Terraform will not warn you beyond this comment, and it will not stop to ask if you're sure that's what you meant.

### 15.6 Variables, Locals & Outputs

Three ways values flow through a config: `variable` for input the caller supplies, `locals` for a value computed once and reused, `output` for a value handed back out.

``` hcl
variable "environment" {
  type        = string
  description = "dev or stg"
  validation {
    condition     = contains(["dev", "stg"], var.environment)
    error_message = "environment must be \"dev\" or \"stg\"."
  }
}

locals {
  name_prefix = "app-${var.environment}"   # computed once, referenced everywhere below
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  tags          = { Name = local.name_prefix }
}

output "instance_public_ip" {
  value       = aws_instance.app.public_ip
  description = "Public IP, for the smoke test after apply."
}
```

!!! note "variable vs locals"

    A `variable` is set from outside the config — a `.tfvars` file, a `-var` flag, an environment variable. A `locals` value is computed inside the config from other values and can never be overridden from outside. If you find yourself wanting to override a `locals` value, it should have been a `variable` from the start.

!!! success "Validation catches typos before AWS does"

    Without the `validation` block above, passing `environment = "staging"` (instead of `"stg"`) would sail through `plan` and only fail deep into `apply` once some downstream resource tries to use it, with a much less obvious error. Same principle as module-level validation (see 16.4), applied to root-level variables too.

#### Outputting a whole count/for_each collection, not just one instance

The `output` above reads one instance's `public_ip` directly. With `count` or `for_each`, there's no single instance to read from — `aws_instance.app` is a collection, one object per index or key. A `for` expression inside the output pulls one attribute out of every entry at once:

``` hcl
resource "aws_instance" "app" {
  count = 3
  # ...
}

output "instance_ids" {
  value       = { for idx, inst in aws_instance.app : idx => inst.id }
  description = "Every instance's ID, keyed by its count index."
}
# result: { 0 = "i-0aaa...", 1 = "i-0bbb...", 2 = "i-0ccc..." }
```

!!! note "This is a map comprehension, not a loop"

    `{ for k, v in collection : k => v.attr }` reads almost exactly like Python's `{k: v.attr for k, v in collection.items()}` — both take an iterable of key/value pairs and return a brand-new map with the same keys but transformed values. Unlike a Python `for` statement, there's no loop body here at all — the whole expression *is* the result, which is true of every `for` in HCL, inside an `output`, a `locals`, or a `for_each` argument alike.

### 15.7 Supplying Variable Values — .tfvars Files and Loading Order

A `variable` block (15.6) declares that an input exists. It doesn't supply a value — that's a separate question, and a `.tfvars` file is the most common answer. It's just a list of assignments, one per variable, no `variable` keyword involved:

``` hcl
# stage.tfvars
instance_type    = "t3.micro"
region           = "ap-south-1"
ami_id           = "ami-0333333333333333"
username_prefix  = "fmk-tf"
app_env          = "staged"
```

A second file, `production.tfvars`, declares the exact same variable names with different values — that's the entire mechanism behind "the same code, different environment." Nothing in `main.tf` changes; only which file gets loaded does.

#### Two ways a .tfvars file actually gets loaded

`terraform.tfvars` (or anything named `*.auto.tfvars`)
:   Loaded automatically, every time — no flag needed. Convenient for a single-environment project, but it means there's nothing in the command line that says which values got used; you'd have to go look at the file.

Any other filename — `stage.tfvars`, `production.tfvars`
:   Never loaded automatically. Requires an explicit `-var-file` flag, every time:
terraform plan  -var-file="stage.tfvars"
terraform plan  -var-file="production.tfvars"
This is the better default for anything with more than one environment — the environment being targeted is now visible in the command itself, not hidden inside a filename someone has to already know to look for.

!!! note "Precedence, when more than one source sets the same variable"

    Lowest to highest: an `TF_VAR_name` environment variable, then `terraform.tfvars`, then any `*.auto.tfvars` files (alphabetical), then every `-var-file` in the order given on the command line, then a bare `-var` flag — highest priority, wins over everything. In practice this rarely needs memorizing in full; the one rule worth keeping is that whatever's passed explicitly on the command line always beats whatever's sitting in a file.

#### A variable with no type accepts anything

``` hcl
# valid HCL -- no type, no default, no description
variable "app_env" {}
```

!!! danger "No type means no validation at all"

    This isn't a shortcut, it's an opt-out. Terraform infers the type from whatever's actually passed at runtime and checks nothing — a `.tfvars` file typo that supplies a list where a string was expected won't be caught here; it'll propagate until something downstream breaks, with an error far away from the actual mistake. It also means the variable is **required** with no visible signal of what shape a caller should supply — compare that to `variable "instance_count"` with `type = number` and `default = 2` (15.6/16.4), which documents both the shape and a safe fallback in three lines. Always give a variable a `type`, even one as loose as `any` — that's still a deliberate choice, not an accident of leaving the argument out.


## 16 Iteration and Modules

The language features that shape everything downstream, then packaging it for reuse.

### 16.1 count vs for_each

Both repeat a resource block. `count` indexes by number (`0`, `1`, `2`…). `for_each` indexes by a stable key from a map or set of strings. That difference is small on day one and expensive a month later.

``` hcl
# count -- indexed by position
resource "aws_subnet" "private" {
  count      = length(var.private_cidrs)
  vpc_id     = var.vpc_id
  cidr_block = var.private_cidrs[count.index]
  tags       = { Name = "private-${count.index}" }
}
# state addresses: aws_subnet.private[0], aws_subnet.private[1], aws_subnet.private[2]

# for_each -- indexed by key
resource "aws_subnet" "private" {
  for_each   = var.private_subnets   # map(object({ cidr = string, az = string }))
  vpc_id     = var.vpc_id
  cidr_block = each.value.cidr
  availability_zone = each.value.az
  tags       = { Name = "private-${each.key}" }
}
# state addresses: aws_subnet.private["a"], aws_subnet.private["b"], aws_subnet.private["c"]
```

!!! danger "The gotcha"

    Remove the middle element from a `count`-driven list and every subnet after it shifts down one index. Terraform doesn't see "one subnet removed" — it sees `[2]` now holding what used to be at `[3]`, so it destroys and recreates every resource from that index onward, not just the one you actually deleted. On a subnet with an attached NAT gateway or an RDS instance, that's an outage triggered by an unrelated one-line diff.

!!! success "The fix"

    `for_each` keys are strings, not positions, so removing one entry (`aws_subnet.private["b"]`) only touches that address — everything else in state is untouched. If you're stuck with a list, convert it to a map keyed by something stable first: `{ for s in var.list : s.name => s }`.

!!! danger "`count.index` only exists where `count` is set"

    Trying to reference `count.index` inside a `locals` block fails outright: `Error: Reference to "count" in non-counted context — The "count" object can only be used in "module", "resource", and "data" blocks, and only when the "count" argument is set.` A `locals` block has no loop of its own to index into. Building a list of per-item values for later use needs a `for` expression with its own loop variable instead — `[for i in range(3) : "name-${i}"]` — then index into that list with `count.index` from inside the resource that actually has `count`.

#### merge() — overriding one key of a map without losing the rest

A common need with `count`/`for_each`: reuse a shared base set of tags on every resource, but give each instance its own `Name`. Assigning `tags` directly replaces the whole map — `merge()` combines two maps instead, with the second map's keys winning on any overlap:

``` hcl
variable "project_environment" {
  type = map(string)
  default = {
    Name  = "app"
    Owner = "fahad"
    Event = "learning-devops-tf"
  }
}

resource "aws_instance" "app" {
  count = 3
  # ...
  tags = merge(
    var.project_environment,
    { Name = "${var.project_environment["Name"]}-${count.index + 1}" }
  )
}
# result per instance: { Name = "app-1", Owner = "fahad", Event = "learning-devops-tf" }
#                       { Name = "app-2", Owner = "fahad", Event = "learning-devops-tf" }  ...
```

!!! danger "Without merge(), the rest of the map silently disappears"

    `tags = { Name = "app-${count.index + 1}" }` on its own is valid HCL — it just replaces `tags` entirely, so `Owner` and `Event` quietly vanish from every instance with no warning. `merge(mapA, mapB)` returns a new map containing every key from both — `mapB`'s value wins wherever a key exists in both — which is what lets one shared variable stay the single source of truth for the tags every resource has in common.

|  | `count` | `for_each` |
|---|---|---|
| Index type | Number | String key (map or set) |
| Removing a middle item | Reshuffles and recreates everything after it | Destroys only that one resource |
| Reference syntax | `count.index` | `each.key` / `each.value` |
| Good fit | N identical, disposable copies (e.g. N NAT gateways, one per AZ index) | Anything you'll add to, remove from, or look up by name later |

Default to `for_each`. Reach for `count` only for a genuinely fixed, order-independent replication count, or the simple `count = var.enabled ? 1 : 0` toggle for an optional resource.

### 16.2 Dynamic Blocks

A `dynamic` block generates a repeatable *nested* block from a list or map — for arguments that appear once per resource, plain interpolation is enough; `dynamic` is for things like a security group's `ingress` block, where you need a variable number of them.

``` hcl
variable "ingress_rules" {
  type = list(object({
    port        = number
    cidr_blocks = list(string)
    description = string
  }))
}

resource "aws_security_group" "app" {
  name   = "app-sg"
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }
}
```

!!! note "Only for nested blocks"

    `dynamic` exists because `ingress { ... }` is a nested block, not an argument — you can't just pass it a list the way you'd pass a list to `cidr_blocks`. If the thing you're repeating is a plain argument, you don't need `dynamic` at all; a `for` expression inside the argument is enough.

!!! danger "Readable but easy to overuse"

    A security group with one `dynamic "ingress"` block driven by a well-named variable is clear. Three or four nested `dynamic` blocks inside one resource, each driven by a different variable, is usually a sign the resource wants to be a module instead — dynamic blocks trade explicitness for flexibility, and that trade stops paying off past one level of nesting.

!!! danger "A dynamic block only means anything inside a resource"

    Writing `dynamic "ingress" { ... }` at the top level of a file — not nested inside any `resource` block — fails with `Unexpected block: Blocks of type "dynamic" are not expected here`. A `dynamic` block generates a nested block *for whichever resource it lives inside*; on its own, with no resource around it, Terraform doesn't recognize `dynamic` as a valid block type at all. It has to sit exactly where a literal `ingress { }` block would otherwise go, inside `resource "aws_security_group" "main" { ... }`.

!!! note "ingress.value isn't self-reference — it's a name collision"

    The label on `dynamic "ingress"` does two jobs at once: it says which nested block type to generate, *and* it becomes the default name of the loop variable inside `content { }` — which is why `ingress.value` can look like the block referencing itself. It isn't; it's the same role as `each.value` on a resource-level `for_each`, just defaulting to a name that happens to match the block label. An explicit `iterator` argument removes the ambiguity — add `iterator = rule` alongside `for_each` in the block above, then use `rule.value.port` in place of every `ingress.value.port` inside `content { }`. Same result, but `rule.value` reads unambiguously as "the current item," never as the block calling itself.

### 16.3 `lifecycle` and Explicit Dependencies

Terraform infers most dependencies automatically from references between resources. `lifecycle` and `depends_on` exist for the cases it can't infer, or gets wrong for your situation.

#### lifecycle meta-argument

``` hcl
resource "aws_launch_template" "app" {
  name_prefix   = "app-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "primary" {
  # ...
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [password]   # rotated out-of-band, don't fight it
  }
}
```

`create_before_destroy`
:   Builds the replacement before tearing down the original. Without it, a launch template change destroys the old template first — if the new one fails to create, the ASG is left pointing at nothing. Essential for anything an ASG or ALB target group references.

`prevent_destroy`
:   Makes `terraform destroy` (and any plan that would replace the resource) fail loudly instead of deleting it. Use it on anything with data you can't regenerate from code — the primary database, not the ASG.

`ignore_changes`
:   Tells Terraform to stop diffing specific attributes, even if the real resource drifts from what's in config. Use it for values something else legitimately manages (autoscaling-adjusted `desired_capacity`, a password rotated by Secrets Manager) — never as a blanket way to silence a diff you don't understand.

!!! danger "prevent_destroy blocks real teardown too"

    It doesn't distinguish "someone fat-fingered `destroy`" from "we're intentionally decommissioning this." A genuine teardown means removing the `lifecycle` block (or setting `prevent_destroy = false`) first, applying that change, then destroying — an explicit two-step, by design.

#### Explicit depends_on

Terraform sees a dependency wherever one resource's argument references another resource's attribute. `depends_on` is for ordering that exists only in AWS's behavior, not in any attribute reference — e.g. an IAM role's policy attachment finishing before the compute resource that assumes that role is created.

``` hcl
resource "aws_ecs_service" "app" {
  # nothing here references aws_iam_role_policy_attachment.ecs_exec directly,
  # but the task will fail to start if the permissions aren't attached yet
  depends_on = [aws_iam_role_policy_attachment.ecs_exec]
  # ...
}
```

!!! success "Reach for it last"

    Every explicit `depends_on` is a sign Terraform couldn't infer the relationship from your config. Before adding one, check whether restructuring the reference (e.g. reading the role's ARN from an output instead of hardcoding it) would let Terraform infer the same ordering automatically — that stays correct even if the resources are later refactored.

### 16.4 Module Interface Design

A module's `variables.tf` and `outputs.tf` are its API. Everything inside `main.tf` is an implementation detail the caller shouldn't need to know about.

``` hcl
# variables.tf
variable "name" {
  type        = string
  description = "Prefix applied to every resource this module creates."
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for the ASG's launch template."
  validation {
    condition     = can(regex("^t3\\.", var.instance_type))
    error_message = "Only t3.* instance types are approved for this environment."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC to launch into. No default -- callers must be explicit."
}

# outputs.tf
output "asg_name" {
  value       = aws_autoscaling_group.this.name
  description = "Name of the created Auto Scaling Group, for attaching alarms."
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "SG ID, so callers can add extra ingress rules without editing this module."
}
```

!!! note "Required vs optional"

    A variable with no `default` is required — the caller must supply it, and Terraform refuses to plan without it. That's the right choice for anything with no safe guess (`vpc_id`, `name`). Give a `default` only to genuinely optional knobs (`instance_type`, tag overrides) — defaulting something like `vpc_id` "for convenience" is how a module quietly gets applied into the wrong VPC.

!!! success "Validate at the boundary"

    A `validation` block turns "the apply failed 4 minutes in with an opaque AWS error" into "the plan refused to run with a one-line message," for the exact same underlying mistake. Put constraints you already know at input time (allowed instance families, CIDR shape, name length limits) into `validation` blocks rather than discovering them from a provider error.

Pin the module's own required versions too, so a caller can't apply it against an incompatible Terraform or provider release without being told explicitly:

``` hcl
# versions.tf
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

#### Shaping data at the boundary between two modules

A module's output doesn't have to hand back exactly what it holds internally — narrowing it to just what the next module needs is itself part of interface design. `day02-modules/main.tf` does exactly this when wiring `network`'s output into `compute`'s input:

``` hcl
module "compute" {
  source = "./modules/compute"
  subnet_ids = { for az, subnet in module.network.public_subnets : az => subnet.id }
  # ...
}
```

`module.network.public_subnets` is a map of *whole subnet objects* (id, cidr_block, arn, tags — everything). `compute`'s `subnet_ids` variable only wants plain ID strings. The for-expression bridges that gap:

``` text
module.network.public_subnets                    the for-expression's result
{                                                  {
  "1a" = { id = "subnet-0aaa...",                    "1a" = "subnet-0aaa..."
            cidr_block = "11.0.1.0/24",     -->       "1b" = "subnet-0bbb..."
            arn = "...", tags = {...} }              }
  "1b" = { id = "subnet-0bbb...", ... }
}
```

!!! success "Same keys in, same keys out"

    `for az, subnet in ... : az => subnet.id` keeps every key exactly as it was (`"1a"`, `"1b"`) and replaces only the value — the whole subnet object collapses down to just its `.id`. This is the same map-to-map for-expression as 15.6's collection output, just used at a module boundary instead of in an `output` block — narrowing a rich internal object down to the one field a caller actually needs, rather than making every downstream module reach into fields it has no business touching.

### 16.5 Versioning & Sourcing Modules

Where a module's code lives, and how a caller pins to a specific version of it, has direct consequences for whether a `plan` run next month reproduces the one you ran today.

| Source | Syntax | Reproducible? |
|---|---|---|
| Local path | `source = "../modules/network"` | Yes, but only within one repo — fine for this ramp plan's single-repo layout |
| Git, floating branch | `source = "git::https://.../network.git?ref=main"` | No — `main` keeps moving, the same config can resolve to different code tomorrow |
| Git, pinned tag | `source = "git::https://.../network.git?ref=v1.4.0"` | Yes — a tag is (by convention) immutable |
| Terraform Registry | `source = "app.terraform.io/org/network/aws"`, `version = "~> 1.4"` | Yes, with the added benefit of registry-enforced semver |

``` hcl
module "network" {
  source  = "git::https://github.com/example-org/tf-modules.git//network?ref=v1.4.0"
  name    = "app"
  vpc_cidr = "10.0.0.0/16"
}

module "ecs_service" {
  source  = "app.terraform.io/example-org/ecs-service/aws"
  version = "~> 2.1"

  name        = "api"
  cluster_arn = module.ecs_cluster.arn
}
```

!!! danger "A floating ref isn't a version"

    `?ref=main` means "whatever the module author most recently pushed." Two engineers running `terraform plan` an hour apart, on the exact same calling code, can get different plans if `main` moved in between — and there's no diff in your own repo to explain why. Always pin to a tag or a full commit SHA, never a branch name.

!!! success "Semver on the module itself"

    A published module should bump its major version on any breaking interface change (a variable removed, a required input added, an output renamed) — exactly like a library. Callers then use `~>` constraints to accept patch/minor updates automatically while breaking changes require a deliberate version bump in the caller's own code.

### 16.6 Composition vs Over-Abstraction, and Repo Layout

A module is worth the indirection when it's used more than once, or when its interface has genuinely stabilized. Before either is true, a module is just a resource block wearing a costume — one more file to open to see what actually gets created.

!!! success "Rule of three"

    Write the resource inline the first time. Copy it the second time. Only extract a module the third time a near-identical block shows up — by then the actual variable inputs (what really differs between the three copies) are obvious, instead of guessed at up front.

!!! danger "Over-abstraction looks like caution"

    A module with 40 input variables "for flexibility," most of which every caller sets to the same default, isn't reusable — it's one specific configuration with extra steps. It hides the actual resource shape from anyone reading the calling code, and every new requirement means threading one more variable through the whole interface. If every caller passes the same value for a variable, that value belongs inside the module, not in its interface.

#### A repository layout that survives a year of change

``` text
.
├── modules/
│   ├── network/          # VPC, subnets, route tables, NAT
│   ├── security-groups/
│   ├── compute-asg/      # launch template + ASG + target group attachment
│   └── ecs-service/      # task def + service, one block per microservice
├── environments/
│   ├── dev/
│   │   ├── main.tf       # calls the modules above with dev's variable values
│   │   ├── backend.tf    # dev's remote state config
│   │   └── terraform.tfvars
│   └── stg/
│       ├── main.tf       # same module calls, staging's variable values
│       ├── backend.tf
│       └── terraform.tfvars
└── .github/workflows/    # or Jenkinsfile -- fmt, validate, plan-on-PR
```

The two environment directories call the *same* modules with different variable values and a different backend key — that's what makes "dev and stg differ only by variable values" (this week's deliverable) actually true, rather than aspirational. Nothing about a module's internals should need to know which environment is calling it.

### 16.7 Provisioners — file, connection, and Why They're a Last Resort

Everything so far declares *desired state* — Terraform figures out the API calls. A `provisioner` is the one place that breaks that model: it runs an imperative action (upload a file, run a script) against a resource right after it's created, over SSH or WinRM. It needs a `connection` block to say how to actually log in — which needs a real key pair to exist first.

#### Generating a key pair to a custom path

`ssh-keygen` prompts for a save location; pointing it somewhere other than the default `~/.ssh/id_rsa` keeps a project-specific key out of your global SSH config:

``` bash
ssh-keygen -t rsa -b 2048
# Enter file in which to save the key (~/.ssh/id_rsa): ./deployer_key
# Enter passphrase (empty for no passphrase): [leave blank for a provisioner -- see note below]
```

This writes two files: `deployer_key` (the **private** key — never committed, never shared) and `deployer_key.pub` (the **public** key — safe to share, this is what AWS actually stores). Terraform reads the public half into `aws_key_pair`, and the private half into the `connection` block below to actually authenticate:

``` hcl
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("./deployer_key.pub")
}
```

!!! danger "A hand-typed key is one truncation away from a real error"

    A public key pasted or retyped as an inline string is easy to accidentally clip — a real `apply` once failed with `InvalidKey.Format: Key is not in valid OpenSSH public key format` because the leading `AAAAB3NzaC1yc2E...` chunk (a fixed, required part of every RSA key's encoding) got cut off during a copy-paste. Reading the key with `file("./deployer_key.pub")`, as above, removes the chance of that entirely — the exact bytes `ssh-keygen` wrote are what gets sent, nothing retyped in between.

!!! danger "key_name = "a-string" isn't a reference — it's a coincidence"

    `key_name = "deployer-key"` on the instance and `key_name = "deployer-key"` on the `aws_key_pair` happening to match is invisible to Terraform's dependency graph (15.3) — a bare string creates no edge between the two resources. A real `apply` creating both at once launched the EC2 instance and the key pair *in parallel*, and the instance's `RunInstances` call reached AWS before the key pair existed, failing with `InvalidKeyPair.NotFound` even though the key pair resource itself succeeded moments later in the same apply. The fix is the reference already used above — `key_name = aws_key_pair.deployer.key_name` — which both names the actual key and forces the correct creation order, the same mechanism 15.3 covers for any two resources that need to happen in sequence.

!!! danger "An empty passphrase is the practical choice for a provisioner"

    An SSH key with a passphrase demands it interactively on every connection — but the `file` provisioner authenticates non-interactively, with no way to type a passphrase in when Terraform asks. A passphrase-protected key here just fails auth silently, the same "looks like a hang, not an error" symptom as the wrong-username case below. For a key that automation (not a human at a terminal) is going to use, leave the passphrase blank.

``` hcl
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.main.id]

  provisioner "file" {
    source      = "./provisioned_file.txt"
    destination = "/home/ec2-user/provisioned_file.txt"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file("./deployer_key")
    timeout     = "4m"
  }
}
```

!!! danger "Wrong SSH user looks like a hang, not an error"

    A real `apply` using `user = "ubuntu"` against an Amazon Linux 2023 AMI sat at `Still creating...` for over 4 minutes with no error message at all — because Amazon Linux's login user is `ec2-user`, not `ubuntu` (the same AMI-dependent-username gotcha as compute.html's SSH troubleshooting, showing up again here). Every failed SSH attempt is silently retried until the `connection` block's own `timeout` is exhausted, so a wrong username doesn't fail fast — it fails slow, looking exactly like a stuck instance. Match the user to the AMI family: `ec2-user` for Amazon Linux, `ubuntu` for Ubuntu, `admin` for Debian.

!!! danger "The destination path needs to be writable by that user"

    Fixing the username above can surface a second, different failure: `scp: /home/provisioned_file.txt: Permission denied`. `/home/` itself is owned by `root` — no login user can write directly into it, only into their own subdirectory one level down (`/home/ec2-user/`). `/tmp` is the simpler default destination when the exact home directory isn't worth hardcoding, since it's world-writable regardless of which user connects.

#### local-exec — runs on your machine, not the resource

Easy to misread at first: `local-exec` runs its command on whatever machine is running `terraform apply` — never on the resource itself, and it needs no `connection` block at all, because it never connects to anything.

``` hcl
resource "aws_instance" "app" {
  # ...
  provisioner "local-exec" {
    command = "touch hello.txt"
  }
}
```

!!! danger ""touch hello.txt" doesn't touch the instance"

    A real run of the block above created `hello.txt` sitting in the same directory `terraform apply` was run from — not on the EC2 instance, not anywhere in AWS. `local-exec` is for side effects on the machine running Terraform itself: writing an output value to a local file, triggering a local notification, kicking off a script that talks to some other system entirely. To actually run a command *on* the resource, the provisioner needed is `remote-exec`, next.

#### remote-exec — runs commands on the resource, over the same connection

Same `connection` block as `file` (SSH, same host/user/key) — but instead of uploading a file, it runs shell commands directly on the remote resource:

``` hcl
resource "aws_instance" "app" {
  # ...
  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y httpd",
      "sudo systemctl enable --now httpd"
    ]
  }
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file("./deployer_key")
  }
}
```

!!! note "inline vs script vs scripts"

    `inline` (above) is a list of commands run in order, each over its own SSH exec call — fine for two or three lines. `script` uploads and runs one local script file; `scripts` does the same for a list of them. For anything longer than a handful of commands, a script file is easier to read, test locally, and version — the same reasoning that already favors a `userdata.sh` file (5.2 of compute.html) over an inline heredoc.

!!! note "Prefer user_data over a provisioner whenever the choice exists"

    `user_data` (15.2, 18.8.1 section 9) runs as part of the instance's own boot process — no SSH session, no network round-trip from wherever `apply` happens to run, no connection timeout to tune. A provisioner needs Terraform itself to hold an SSH connection open during `apply`, which means it can fail for reasons that have nothing to do with the resource being wrong — a security group change, a flaky network, a key mismatch. HashiCorp's own guidance is to treat provisioners as a last resort, for the narrow cases `user_data` genuinely can't cover (pulling a file that doesn't exist until another resource in the same `apply` finishes, for instance) — not as the default way to configure a new instance.

#### SSHing in yourself afterward — the same key, a manual connection

Everything above wires a key pair into an instance so *Terraform's own* provisioner can log in. Logging in yourself afterward, from a terminal, reuses the exact same key pair — no separate setup:

``` bash
chmod 400 ./deployer_key   # SSH refuses a private key that's readable by anyone else
ssh -i "./deployer_key" ec2-user@<instance-public-dns-or-ip>
```

!!! danger "The ingress CIDR means "from," never "to""

    A real security group ended up with its port-22 rule allowing the EC2 instance's own public IP — which looked plausible, since that's literally the address baked into the instance's own hostname (`ec2-203-0-113-10...`). But an ingress `cidr_blocks` always means "traffic is allowed to arrive *from* this address" — never "this is the address being connected to." The instance's own IP is irrelevant to its own ingress rules; what belongs there is the **client's** IP — the machine running `ssh`, found with `curl ifconfig.me`, not the server being connected to. Getting this backwards produces the same silent, response-less hang as any other SG mismatch — nothing distinguishes "wrong direction" from "wrong IP entirely" at the network level.

!!! danger "A hardcoded personal IP goes stale"

    Locking SSH to "just my IP" via a `/32` CIDR is good practice over `0.0.0.0/0`, but most home and mobile ISPs assign dynamic addresses — the correct CIDR today can silently stop working after a router reboot or a network change, with the exact same symptom as every other SG mismatch: `ssh` just hangs, no error to point at the real cause. Re-running `curl ifconfig.me` and comparing it against the security group's current rule is the fastest way to rule this in or out before suspecting the key, the instance, or anything else.

### 16.8 Templating: templatefile() and .tftpl Files

18.9 built a Lambda IAM policy with `jsonencode({...})` — real HCL values, mechanically serialized into JSON. `templatefile()` is the other approach: write the JSON (or a script, or any text) as its own file, with `${...}` placeholders, and have Terraform render it with real values substituted in.

``` hcl
# main.tf
resource "aws_iam_user_policy" "instance_manager" {
  name = "InstanceManagePolicy"
  user = aws_iam_user.created_user.name
  policy = templatefile("${path.module}/user-policy.tftpl", {
    ec2_policies = [
      "ec2:RunInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances",
      "ec2:RequestSpotInstances",
    ]
  })
}
```

``` text
# user-policy.tftpl
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ${jsonencode(ec2_policies)},
            "Resource": "*"
        }
    ]
}
```

`templatefile(path, vars)` takes two arguments: the file to render, and a map of variables the template can reference. Inside the `.tftpl` file, `${ec2_policies}` would insert a raw HCL representation of the list — wrapping it in `jsonencode(...)`, as above, is what turns it into valid JSON array syntax instead.

#### Why reach for a separate file at all

Nothing here is impossible with `jsonencode()` alone — the difference is where the content lives. A large JSON policy, a multi-line bootstrap script, or an nginx config reads far more naturally as its own properly-formatted file (real syntax highlighting, no HCL string-escaping) than as a nested HCL data structure. `templatefile()` also supports its own mini control-flow syntax inside the template file itself — a `for` directive and an `if` directive, the template-text equivalents of a `for` expression (15.6) and a conditional.

#### %{ for } — repeating a line once per item

``` hcl
# allowed_ips.tftpl
%{ for ip in allowed_ips ~}
allow ${ip};
%{ endfor ~}
deny all;
```

``` hcl
templatefile("${path.module}/allowed_ips.tftpl", {
  allowed_ips = ["203.0.113.10", "203.0.113.20"]
})
```

``` text
# rendered output
allow 203.0.113.10;
allow 203.0.113.20;
deny all;
```

!!! note "The ~ is a whitespace-strip marker, not part of the loop"

    Without `~`, every `%{ for ... }` and `%{ endfor }` line still emits its own trailing newline into the output — a template written across multiple lines would render with extra blank lines where the directive lines themselves used to be. `%{ for ip in allowed_ips ~}` strips the newline immediately after the directive; `%{ endfor ~}` does the same before it. The result is clean output with no artifacts from the directive syntax itself — always worth adding on multi-line `for`/`if` directives unless you've checked the output without it and it already looks right.

A key-value version works the same way as a two-variable `for` expression (16.1's `each.key`/`each.value` pattern, here as template text instead):

``` hcl
%{ for name, port in services ~}
${name}: ${port}
%{ endfor ~}
```

#### %{ if } / %{ else } — conditional content

``` hcl
# userdata.tftpl
#!/bin/bash
yum install -y httpd
%{ if enable_monitoring ~}
yum install -y amazon-cloudwatch-agent
systemctl enable --now amazon-cloudwatch-agent
%{ else ~}
echo "monitoring agent skipped"
%{ endif ~}
systemctl start httpd
```

``` hcl
user_data = templatefile("${path.module}/userdata.tftpl", {
  enable_monitoring = var.enable_monitoring   # a plain bool
})
```

`%{ else }` is optional — a bare `%{ if ... }`/`%{ endif }` with nothing in between the false branch and `endif` simply renders nothing when the condition is false, the same as an `if` with no `else` in most languages.

#### Indenting a directive line leaks whitespace into the output

Indenting `%{ if }`/`%{ for }` to match the surrounding code is natural — but `~` only strips whitespace on the side of the directive it's placed on. A trailing-only `~}` does nothing about the spaces typed *before* `%{` on that same line:

``` text
#!/bin/bash
    %{ if enable ~}
    yum install -y agent
    %{ endif ~}
systemctl start httpd
```

``` text
# actual rendered output -- verified directly
#!/bin/bash
        yum install -y agent
    systemctl start httpd
```

!!! danger "The indentation doesn't just appear, it accumulates"

    `yum install -y agent` rendered with **8** leading spaces, not 4 — its own indentation plus the 4 unstripped spaces sitting before `%{ if enable ~}` on the line above, since only that directive's trailing newline was stripped, not its leading whitespace. `systemctl start httpd` — which had no indentation in the source at all — picked up 4 leading spaces leaked from the `%{ endif ~}` line the same way. The whitespace doesn't just leak, it silently shifts onto lines that were never indented in the source.

The fix is `~` on *both* sides of a directive-only line — `%{~ if enable ~}` — which strips the leading whitespace/newline too:

``` text
#!/bin/bash
    %{~ if enable ~}
    yum install -y agent
    %{~ endif ~}
systemctl start httpd
```

``` text
# rendered output -- clean
#!/bin/bash
    yum install -y agent
systemctl start httpd
```

!!! success "Default to both-sided ~ on directive-only lines"

    A line that contains nothing but a `%{ if }`/`%{ for }`/`%{ endif }`/`%{ endfor }` directive is never meant to produce output itself — it exists purely for control flow. `%{~ ... ~}` on every such line is the safe default; reach for one-sided `~` only when a directive shares a line with real content you specifically want to keep.

`%{ for }`/`%{ if }` aren't a `templatefile()`-only feature — they're part of HCL's general template syntax, usable inside *any* string expression, including a heredoc written directly in a resource block, with no separate file at all:

``` hcl
user_data = <<-EOF
  #!/bin/bash
  %{ if enable_monitoring ~}
  yum install -y amazon-cloudwatch-agent
  %{ endif ~}
EOF
```

!!! success "templatefile() only changes where the text lives"

    The directive syntax above is identical whether it's inline in a heredoc or inside a file read by `templatefile()` — the only thing `templatefile()` adds is reading that text from a separate file instead of writing it directly in the resource block.

|  | `jsonencode({...})` | `templatefile("...tftpl", {...})` |
|---|---|---|
| Where the content lives | Inline, inside the `.tf` file, as real HCL values | A separate file, with `${...}` placeholders |
| Syntax correctness | Guaranteed valid JSON — it's built mechanically, never hand-typed | Only as correct as whatever's typed in the template file — a missing comma is a real, hand-made mistake |
| Good for | Policies and structures that are naturally HCL-shaped already (lists, maps you're already building) | Long or reused text — multi-line scripts, large policies, anything an editor should syntax-highlight properly |
| Failure mode | A typo is a normal HCL error, caught early and clearly | A typo can be a raw JSON parse error with a byte offset (15.5-style plan-time failure, but far less readable) |

!!! danger "This is the exact error a missing comma produces"

    A real `plan` against the template above (before its comma was added) failed with `"policy" contains an invalid JSON policy: invalid character '"' after object key:value pair, at byte offset 35`. That's what `templatefile()`'s tradeoff looks like in practice: the file is plain text as far as Terraform's HCL parser is concerned, so a hand-typed JSON mistake surfaces as a raw JSON parser complaint, not a clean, typed HCL error the way a mistake inside `jsonencode({...})` would.

!!! danger "Neither approach checks that the action names are real"

    Fixing the JSON syntax doesn't mean the policy is correct — `"ec2:RequestSpotInstance"` (singular) parsed as perfectly valid JSON and passed `templatefile()` without complaint, but AWS itself rejected it: the real action is `RequestSpotInstances` (plural). Neither `jsonencode()` nor `templatefile()` validates that an IAM action actually exists — that check only happens once AWS evaluates the policy, at `apply` time, regardless of which method built the JSON.

### 16.9 null_resource — Provisioners With No Real Infrastructure Attached

Every provisioner (16.7) has to live inside some `resource` block — but sometimes the action you want (run a script, hit a webhook, invalidate a cache) doesn't correspond to creating any real cloud resource at all. `null_resource` is a resource that creates nothing in AWS — it exists purely to give a provisioner (or a dependency edge) somewhere to attach.

``` hcl
resource "aws_instance" "app_server" {
  ami           = "ami-08188a5a4dfdbd573"
  instance_type = "t3.micro"
  tags          = { Name = "app-server" }
}

resource "null_resource" "notify_on_change" {
  triggers = {
    instance_id = aws_instance.app_server.id
  }

  provisioner "local-exec" {
    command = "echo Hello World"
  }
}
```

!!! note "Why triggers exists"

    A `null_resource` has no real attributes of its own, so on a normal `apply` nothing about it ever looks "changed" — Terraform would never know to re-run its provisioner again. `triggers` is the workaround: any change to a value inside that map (here, `aws_instance.app_server.id`, which changes whenever that instance is replaced) marks the `null_resource` itself as needing replacement, which re-runs its provisioner. Without a matching entry in `triggers`, the provisioner would only ever run once, on the very first `apply`, no matter what changed afterward.

#### When to reach for it

- Running a script that depends on more than one resource finishing, with no single natural resource to attach the provisioner to
- Invalidating a CDN cache (CloudFront) right after a new S3 deployment
- Running a one-off database migration or seed script once the app server and database both exist
- Sending a deploy notification (Slack, a webhook) after other resources finish applying
- Re-running a local script whenever an unrelated value changes — e.g. `triggers = { script_hash = filemd5("deploy.sh") }`, re-running only when that specific file's contents change

!!! danger "Still bound by 16.7's caution about provisioners generally"

    `null_resource` doesn't make provisioners any less of a last resort — it just removes the "which resource do I attach this to" obstacle. Everything from 16.7 still applies: it needs Terraform to hold a connection/process open during `apply`, and it can fail for reasons that have nothing to do with real infrastructure being wrong.

!!! success "terraform_data is the newer, provider-free equivalent"

    Terraform 1.4+ ships `terraform_data` as a built-in resource (no separate `null` provider required) covering the same role — a resource with no real infrastructure, driven by a `triggers_replace` argument instead of `triggers`. `null_resource` still works and remains extremely common in existing code, but new code on a recent Terraform version has one fewer provider to declare by reaching for `terraform_data` instead.

### 16.10 depends_on — Use Cases, Pros and Cons

16.3 introduced `depends_on` for the case a reference can't express — an IAM policy attachment finishing before something that needs it starts. That's the only reason it exists at all: everywhere Terraform *can* see a dependency (one resource's argument reading another resource's attribute, 15.3), it already orders things correctly on its own. `depends_on` only matters for the remaining cases where the real-world ordering requirement leaves no trace in any argument.

#### Real use cases

- A provisioner or `user_data` script that needs another resource to exist first, but only refers to it by a hardcoded name or convention — never a real attribute reference (an S3 bucket a startup script downloads from, named as a plain string rather than `aws_s3_bucket.x.id`)
- IAM permissions that must be attached before a dependent resource starts using them (16.3's example)
- An AWS-side ordering requirement that isn't visible through any argument at all — something that only shows up as a real API error when created in the wrong order
- Forcing a `data` source to read *after* a resource is created, when the data source's own arguments don't reference that resource directly
- Ordering an entire `module` block relative to another resource or module — `depends_on` works on modules too, waiting for every resource inside the whole module to finish

#### A real file with both a correct use and a redundant one

``` hcl
resource "aws_instance" "app" {
  # ...
  vpc_security_group_ids = [aws_security_group.main.id]
  key_name                = aws_key_pair.deployer.key_name

  depends_on = [
    aws_s3_bucket.bucket,        # correct -- nothing above references this bucket at all
    aws_security_group.main,    # redundant -- already inferred from vpc_security_group_ids
    aws_key_pair.deployer,      # redundant -- already inferred from key_name
  ]
}
```

!!! danger "Spot the redundant entries"

    Only `aws_s3_bucket.bucket` belongs in this `depends_on` — nothing in the resource block references any attribute of that bucket, so Terraform has no other way to know it should exist first. `aws_security_group.main` and `aws_key_pair.deployer` are already ordered correctly by `vpc_security_group_ids` and `key_name` — listing them again in `depends_on` changes nothing about how `apply` behaves, it's just dead weight that makes a reader wonder if there's a hidden reason for the dependency beyond what's already visible in the arguments above it.

#### Pros

- Makes a real ordering requirement explicit and visible in code, for the cases where no argument reference could express it
- One `depends_on` can list several resources at once for a single combined ordering constraint
- Works on `data` sources and whole `module` blocks, not just resources

#### Cons

- Operates on the *whole* resource, not a specific attribute — Terraform waits for everything about the other resource to finish, even if only one small part of it actually matters, which can serialize applies more than necessary
- Explains *that* two resources are related, never *why* — a reference shows the actual attribute being used; a bare `depends_on` entry needs a comment to mean anything to the next reader
- Easy to add "just in case" without confirming it's actually needed — as the redundant entries above show, once one is added nothing forces anyone to remove it later, even after it stops meaning anything
- Silently masks a design that could be improved — the "reach for it last" principle from 16.3 exists because restructuring toward a real reference is often possible and stays correct automatically through future refactors, where a `depends_on` entry has to be remembered and kept in sync by hand


## 17 State, Environments and Regions

What state actually holds, and how one codebase serves multiple environments and regions safely.

### 17.1 What State Holds

Terraform can't ask AWS "what does my config manage?" — AWS just has resources, with no concept of which ones "belong" to a given `.tf` file. The state file is Terraform's own record of that mapping: for every resource block, it stores the real resource ID and every attribute AWS returned when it was created.

``` json
{
  "resources": [
    {
      "type": "aws_instance",
      "name": "app",
      "instances": [
        {
          "attributes": {
            "id": "i-0aaa1111aaaa11111",
            "ami": "ami-0111111111111111",
            "instance_type": "t3.micro",
            "public_ip": "203.0.113.10"
          }
        }
      ]
    }
  ]
}
```

Every `plan` is really a three-way comparison: your `.tf` files (desired), the state file (what Terraform believes it last created), and a fresh read of the real AWS API (what actually exists). A mismatch between the last two is **drift** — someone changed the security group by hand in the console, and state doesn't know yet.

!!! danger "Never hand-edit the state file"

    It's JSON, so it's tempting to fix a stuck reference by hand. Don't — a malformed edit corrupts every future plan silently. Use `terraform state` subcommands (Day 19) for anything that looks like a state surgery.

!!! danger "State contains secrets in plaintext"

    An RDS password passed as a resource argument ends up readable in plaintext inside the state file, even if the variable itself is marked `sensitive` (that only hides it from CLI output, not from the file). This is the whole reason state must live in a backend with access control, never committed to git.

### 17.2 Remote Backend with Locking

By default, state lives in a local `terraform.tfstate` file next to your config — fine solo, broken the moment a second engineer runs `apply` from their own laptop against their own copy of that file. A **remote backend** moves state to shared storage; **locking** stops two applies from racing against it at the same time.

``` hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "fahad-terraform-state"
    key            = "dev/network/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"   # locking, pre-2023 syntax
    encrypt        = true
  }
}
```

!!! danger "The backend block doesn't inherit the provider's profile"

    A real `terraform init -migrate-state` failed with `403 Forbidden` on the S3 bucket, even though the exact same bucket worked fine for every other command. Cause: the `backend "s3" { }` block above has no `profile` argument, so it never inherits `profile = "fahad"` from the `provider "aws" { }` block below it — backend initialization happens before providers are even loaded, so nothing carries over automatically. With no explicit profile, it silently fell back to this machine's *default* AWS credential chain, which resolved to a completely different AWS account that had no access to the bucket at all. The fix is adding `profile = "fahad"` directly inside the `backend` block — it needs its own credentials, stated explicitly, every time.

|  | Local state | S3 remote state |
|---|---|---|
| Collaboration | Breaks the moment a second person runs `apply` from their own copy | One shared source of truth for the whole team |
| Locking | None — two concurrent applies can corrupt it | DynamoDB or S3-native locking (above) prevents the race |
| Durability | One laptop's disk — no backup, one `rm` away from gone | S3's own durability, plus optional bucket versioning for point-in-time recovery |
| Setup complexity | Zero — works with no configuration | Needs a bucket, IAM permissions, and its own credential config (see the fact box above) |
| Credential scope | Same identity as everything else automatically | Resolved independently of the provider block — easy to misconfigure, as above |
| Cost | Free | Small S3 storage/request cost, plus DynamoDB cost only if not using native locking |

!!! note "S3 native locking (Terraform ≥ 1.10 / AWS provider ≥ 5.x)"

    Newer Terraform versions can lock directly on the S3 object using conditional writes — no separate DynamoDB table required. Either approach solves the same problem: without locking, two `apply` runs starting seconds apart both read the same "before" state and can each write back a "after" that discards the other's changes.

#### Migrating dynamodb_table to use_lockfile

A real `apply` on Terraform 1.16 produced a live deprecation warning:

``` text
│ Warning: Deprecated Parameter
│
│ The parameter "dynamodb_table" is deprecated.
│ Use parameter "use_lockfile" instead.
```

The fix is a one-line swap in the backend block:

``` hcl
backend "s3" {
  bucket       = "fmk-terraform-backup"
  key          = "tf-state/locking/terraform.tfstate"
  region       = "ap-south-1"
  use_lockfile = true          # was: dynamodb_table = "dynamodb-state-locking"
  profile      = "fahad"
}
```

``` bash
terraform init -reconfigure   # not -migrate-state -- the bucket/key didn't move,
                              # only the locking mechanism did
```

!!! note "-reconfigure vs -migrate-state"

    Changing any backend argument makes Terraform refuse to proceed until you tell it what to do with existing state — but which flag depends on *what* changed. `-migrate-state` is for when the state's actual location changed (a different bucket or key) and the old state needs copying into the new location. `-reconfigure` is for when the location is identical and only settings like this one changed — it just re-applies the new config against the state that's already sitting right there, no copying needed. Using `-migrate-state` when nothing moved, or vice versa, is a common way to get a confusing error instead of the migration you meant.

!!! success "The old DynamoDB table isn't automatically cleaned up"

    Switching to `use_lockfile` just stops *this config* from using the table — it doesn't delete it, and doesn't check whether anything else still depends on it. Safe to delete only after confirming no other project's backend still points at the same `dynamodb_table`.

``` bash
# What locking looks like when it's doing its job
$ terraform apply
Acquiring state lock. This may take a few moments...
Error: Error acquiring the state lock

Lock Info:
  ID:        7c2f9e1a-...
  Path:      dev/network/terraform.tfstate
  Operation: OperationTypeApply
  Who:       teammate@laptop
```

!!! success "This is what makes CI safe"

    Remote state with locking is the prerequisite for the whole Week 5 pipeline — a Jenkins job applying on merge and an engineer running `plan` locally have to share one source of truth, or the pipeline's idea of "current state" silently diverges from reality.

#### Reading and overwriting remote state directly: pull and push

``` bash
# Read-only -- download the current remote state, print it to stdout
terraform state pull > state-snapshot.json

# Inspect it without needing raw S3/console access
terraform state pull | jq '.resources[].name'

# Dangerous -- unconditionally overwrite the remote state with a local file
terraform state push state-snapshot.json
```

|  | `state pull` | `state push` |
|---|---|---|
| Direction | Remote → local (a copy) | Local → remote (overwrites it) |
| Touches real state? | No — read-only, always safe to run | Yes — replaces whatever the remote currently holds |
| Good for | Inspecting or scripting against state (piping into `jq`) without console/S3 access | Recovering from a known-good backup, or a manual fix nothing else can do |
| The catch | A point-in-time snapshot — stale the moment anyone else applies after you pulled it | No diff, no plan, no confirmation prompt shown first — a stale or wrong local file silently erases what Terraform knows about real infrastructure |

!!! danger "push is a last resort, not a routine command"

    `state push` normally refuses to run if the remote state has moved on since your local copy was pulled (compared by an internal serial number) — that check exists specifically to stop exactly the accident this command makes possible. Overriding it with `-force` removes that last safety check entirely. Reach for `terraform state mv`/`rm` (19.4) for routine state surgery; `push` is for genuine disaster recovery, not day-to-day use.

### 17.3 Environment Isolation — Directories vs Workspaces

Two ways to run the same code against `dev` and `stg` without duplicating the resource definitions themselves.

|  | Separate directories | Terraform workspaces |
|---|---|---|
| Structure | `environments/dev/`, `environments/stg/`, each with their own `backend.tf` and `.tfvars` | One directory, `terraform workspace new stg` creates a separate state within the same backend |
| State isolation | Fully separate state files, separate backend keys — a mistake in one physically cannot touch the other | Separate state, same backend config — one bad backend change affects every workspace |
| Blast radius of a bug | A typo in `environments/dev/main.tf` can't reach staging at all | A bug in the single shared `main.tf` reaches every workspace next apply |
| Good fit | Environments that should be able to diverge (different instance sizes, different modules even) and where mistakes must stay contained | Truly identical environments, or short-lived ones (a workspace per PR preview) |

``` bash
# Workspaces, for comparison
terraform workspace new stg
terraform workspace select stg
terraform apply -var-file=stg.tfvars
terraform workspace show   # confirm which one you're about to apply into
```

#### The full terraform workspace command set

`terraform workspace new <name>`
:   Creates a new workspace with its own empty state, and switches to it immediately. Every project starts with one workspace already, called `default` — it's there even if you never run this command.

`terraform workspace select <name>`
:   Switches to an existing workspace. This is the step it's easy to forget before an `apply` — there's no prompt or warning, it just silently applies into whichever workspace was already selected.

`terraform workspace list`
:   Lists every workspace that exists for this configuration, with an asterisk marking the one currently active.

`terraform workspace show`
:   Prints just the name of the currently active workspace — the fast way to confirm what `apply` is actually about to touch, worth running as a habit right before it.

`terraform workspace delete <name>`
:   Removes a workspace and its state file. Terraform refuses if that workspace's state still has resources in it — run `destroy` inside that workspace first, or the delete fails rather than silently orphaning real infrastructure.

!!! danger "The workspace footgun"

    Nothing in the terminal loudly reminds you which workspace is selected — running `terraform apply` after forgetting a `workspace select` applies into whichever one you left active. This repo uses separate directories (see the layout in 16.6) specifically to make that mistake structurally impossible: the environment is which directory you `cd`into, not invisible session state.

#### Pros and cons, specifically for separating credentials

One question workspaces can't answer: do they separate *which AWS account or credentials* an environment uses? No — the `provider "aws" { ... }` block is one static config for the entire run, untouched by which workspace is active.

- **Pro:** fast to spin up — `terraform workspace new` is one command, no new directory or backend config to write.
- **Pro:** state stays genuinely isolated per workspace, even though the config is shared.
- **Pro:** a good fit for short-lived, truly identical environments — a workspace per PR preview, disposable by design.
- **Con:** no credential or account separation at all — every workspace shares the exact same `provider` block, so it can't be the mechanism that keeps `dev` and `prod` on separate AWS accounts.
- **Con:** nothing in the terminal shows which workspace is active — a forgotten `workspace select` applies into whichever one was last left selected.
- **Con:** one shared `main.tf` means one bug reaches every workspace on the next `apply` — no structural containment the way separate directories give you.

### 17.4 Remote State Data Sources Between Layers

Splitting a platform into layers (network, then compute, then application) means the compute layer needs values — a VPC ID, a subnet list — that only the network layer's state actually holds. `terraform_remote_state` reads another layer's state as a data source, read-only.

``` hcl
# in the compute layer
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "fahad-terraform-state"
    key    = "dev/network/terraform.tfstate"
    region = "ap-south-1"
  }
}

resource "aws_instance" "app" {
  subnet_id = data.terraform_remote_state.network.outputs.private_subnet_id
  # ...
}
```

!!! note "Only outputs cross the boundary"

    A layer can only read another layer's declared `output` values, not its internal resources — which is exactly the module-interface discipline from 16.4, applied between whole layers instead of between a module and its caller. If compute needs a value the network layer hasn't output yet, the fix is adding that output, not reaching around it.

!!! danger "A layer boundary is also a blast-radius boundary"

    Splitting into layers means a network change requires its own `plan`/`apply`, separate from the compute layer's — you can no longer `apply` the whole platform in one command. That's the tradeoff: smaller, safer applies, at the cost of the multi-layer `apply` sequencing this buys you.

### 17.5 Provider Aliases & a Second Region as a Variable

A `provider` block configures one region (or account). `alias` lets a single config talk to a second one — the mechanism this week's deliverable ("the same code applied to a second region by changing variables only") actually rests on.

``` hcl
# providers.tf
provider "aws" {
  region = var.primary_region     # e.g. "ap-south-1"
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region   # e.g. "eu-west-1"
}

# usage -- everything else about the resource is identical
resource "aws_s3_bucket" "backup" {
  provider = aws.secondary
  bucket   = "${var.name_prefix}-backup-${var.secondary_region}"
}
```

For a full second-region deployment (not just one bucket), the cleaner pattern is calling the same module twice, once per provider:

``` hcl
module "platform_primary" {
  source = "../modules/platform"
  providers = { aws = aws }
  region = var.primary_region
}

module "platform_secondary" {
  source = "../modules/platform"
  providers = { aws = aws.secondary }
  region = var.secondary_region
}
```

!!! success "Why this satisfies the deliverable"

    Nothing inside `modules/platform` hardcodes a region anywhere — every AZ, AMI lookup, and CIDR is already parameterised (this is what "the whole platform in code" in Day 18 actually depends on). Standing up `eu-west-1` becomes calling the module a second time with a different provider alias, not writing new resource blocks.

### 17.6 fmt, validate, a Linter and a Scanner — From the First Commit

Four checks, in order of how cheap they are to run, all before a plan ever touches real AWS:

``` bash
# 1. Formatting -- purely cosmetic, zero false positives
terraform fmt -recursive -check

# 2. Syntax and internal consistency -- catches typos, type mismatches, missing required args
terraform validate

# 3. Linting -- style and correctness rules validate can't see
tflint

# 4. Security scanning -- known-bad patterns (open SG, unencrypted volume, public S3)
tfsec .
# or: checkov -d .
```

`terraform fmt`
:   Rewrites files to canonical indentation and alignment. `-check` makes it exit non-zero instead of rewriting — the form to run in CI, so a PR fails instead of silently reformatting someone's branch.

`terraform validate`
:   Checks the config is internally consistent — references resolve, types match, required arguments are present. It does *not* check against real AWS state; a config can `validate` cleanly and still fail at `apply` because of an actual AWS-side constraint.

`tflint`
:   Catches things that are syntactically valid but wrong — an invalid instance type for the AWS provider, an unused variable, a deprecated argument.

`tfsec` / `checkov`
:   Static security scanners: flag a security group open to `0.0.0.0/0`, an unencrypted EBS volume, a public S3 bucket, before any of it is ever created.

!!! success "This is what "posted as a comment" means in Week 5"

    These four checks are exactly the pull-request gate this week's Assignment A4 and next week's Jenkins pipeline both describe — running them locally now is rehearsal for wiring the identical commands into CI, not a separate step.


## 18 The Whole Platform in Code

Every resource from Weeks 1–3, declared. Nothing new conceptually — this is Day 15–17's language and workflow, applied to the actual shape of the platform.

### 18.1 ALB — Listeners and Rules in Code

The four-resource shape from load-balancing-dns.html 6.1 (load balancer, target group, listener, listener rule) as a module, driven by a map so adding a second path-routed service is a new map entry, not a new resource block.

``` hcl
resource "aws_lb" "app" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "service" {
  for_each = var.services   # map(object({ port = number, health_check_path = string }))
  name     = "${var.name_prefix}-${each.key}-tg"
  port     = each.value.port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check { path = each.value.health_check_path }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.acm_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[var.default_service].arn
  }
}

resource "aws_lb_listener_rule" "path" {
  for_each     = { for k, v in var.services : k => v if k != var.default_service }
  listener_arn = aws_lb_listener.https.arn
  priority     = index(keys(var.services), each.key) + 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[each.key].arn
  }
  condition {
    path_pattern { values = ["/${each.key}", "/${each.key}/*"] }
  }
}
```

!!! note "The 404 from load-balancing-dns.html, encoded as a fixed pattern"

    The `path_pattern` values include both the exact path and the wildcard (`/bar` and `/bar/*`) — this is the fix from the live `/bar` 404 investigation (load-balancing-dns.html 6.1), written once into the module instead of remembered per rule.

### 18.2 Auto Scaling Group in Code

``` hcl
resource "aws_launch_template" "app" {
  name_prefix   = "${var.name_prefix}-"
  image_id      = var.golden_ami_id
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.app.id]
  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.name_prefix}-asg"
  vpc_zone_identifier = var.private_subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  target_group_arns   = [aws_lb_target_group.service[var.default_service].arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.name_prefix}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60
  }
}
```

!!! success "create_before_destroy earns its keep here"

    Changing `golden_ami_id` (a new Golden AMI baked from compute.html 5.3) replaces the launch template. Without `create_before_destroy` (16.3), the ASG would briefly reference a deleted template if the new one failed to create — with it, the new template exists before the old one is removed.

### 18.3 ACM and Route 53 in Code

``` hcl
resource "aws_acm_certificate" "app" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle { create_before_destroy = true }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app.domain_validation_options : dvo.domain_name => dvo
  }
  zone_id = var.hosted_zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_route53_record" "app" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}
```

!!! note "The manual CNAME step from load-balancing-dns.html 6.3, now self-completing"

    `aws_acm_certificate_validation` is what makes `apply` actually wait for DNS validation to finish before moving on — by hand, this was watching `describe-certificates` for `ISSUED`. Here it's one dependency edge, and it means `destroy` then `apply` from empty (this week's deliverable) needs no manual pause at all.

### 18.4 RDS with Parameter and Subnet Groups, Multi-AZ

``` hcl
resource "aws_db_subnet_group" "app" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = var.private_data_subnet_ids   # a distinct subnet tier from app (databases.html 7.1)
}

resource "aws_db_parameter_group" "app" {
  family = "postgres16"
  parameter {
    name  = "log_min_duration_statement"
    value = "500"   # ms -- feeds the slow-query workflow from databases.html 7.5
  }
}

resource "aws_db_instance" "primary" {
  identifier             = "${var.name_prefix}-db"
  engine                 = "postgres"
  engine_version         = "16.4"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  multi_az               = var.environment == "stg"   # Multi-AZ only where the deliverable calls for it
  db_subnet_group_name   = aws_db_subnet_group.app.name
  parameter_group_name   = aws_db_parameter_group.app.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  manage_master_user_password = true   # password generated and rotated in Secrets Manager -- see 18.5
  lifecycle { prevent_destroy = true }
}
```

!!! danger "prevent_destroy is deliberate here, not everywhere"

    Every other resource in this module accepts `destroy` then `apply` from empty (this week's deliverable). The database is the one exception — real data must never disappear because a teardown script ran against the wrong workspace. Tearing down for real means removing this `lifecycle` block first, as an explicit, separate step (16.3).

### 18.5 Secrets Referenced from Secrets Manager, Never Stored

`manage_master_user_password = true` above already keeps the RDS password out of state and out of config entirely — AWS generates it and stores it in Secrets Manager directly. The application still needs to read that secret at runtime, without it ever appearing in a `.tf` file or a plan.

``` hcl
data "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_db_instance.primary.master_user_secret[0].secret_arn
}

# passed to the app as an environment variable pointing at the secret ARN,
# never as the decrypted value -- the app fetches and decrypts it at boot
resource "aws_ecs_task_definition" "order_service" {
  # ...
  container_definitions = jsonencode([{
    name = "order-service"
    secrets = [
      { name = "DB_PASSWORD", valueFrom = aws_db_instance.primary.master_user_secret[0].secret_arn }
    ]
  }])
}
```

!!! danger "A data source that reads a secret still writes it to state"

    The `aws_secretsmanager_secret_version` data source above pulls the plaintext value into Terraform state the moment anything references its `secret_string` attribute — same exposure as 17.1's warning about `sensitive` variables. Prefer passing the secret's **ARN** to the running service (as the ECS task definition does above) and letting the container fetch and decrypt it at boot, so the plaintext value never has a reason to pass through Terraform at all.

### 18.6 A Reusable ECS Service Module

containers.html's order service, task definition and all, as a module — so that a second microservice is one more module call, not a copy-pasted block of ECS resources.

``` hcl
# modules/ecs-service/variables.tf
variable "name" {}
variable "image" {}
variable "container_port" { type = number }
variable "cluster_arn" {}
variable "target_group_arn" {}
variable "desired_count" {
  type    = number
  default = 2
}

# modules/ecs-service/main.tf
resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  container_definitions = jsonencode([{
    name  = var.name
    image = var.image
    portMappings = [{ containerPort = var.container_port }]
  }])
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.name
    container_port   = var.container_port
  }
}

# root: adding a microservice is one block
module "order_service" {
  source            = "./modules/ecs-service"
  name              = "order-service"
  image             = "${var.ecr_repo_url}:order-service-latest"
  container_port    = 8080
  cluster_arn       = aws_ecs_cluster.main.arn
  target_group_arn  = aws_lb_target_group.service["order"].arn
}
```

!!! success "This is the payoff from Day 16"

    The module's interface (16.4) exposes exactly five inputs — everything about clusters, task CPU/memory defaults, and Fargate wiring stays inside the module. A second service, say `payments-service`, is a second `module` block with different values for those five inputs, not a second copy of the task-definition JSON.

### 18.7 The EKS Cluster, Node Group and IRSA

containers.html's second runtime for the same order service, declared. More moving parts than ECS: the control plane, a node group of worker EC2 instances, and IRSA (IAM Roles for Service Accounts) so pods get scoped AWS permissions without static credentials baked into a container image.

``` hcl
resource "aws_eks_cluster" "main" {
  name     = "${var.name_prefix}-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  vpc_config { subnet_ids = var.private_subnet_ids }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.name_prefix}-ng"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = var.private_subnet_ids
  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }
}

# IRSA -- lets the order-service pod assume an IAM role scoped to just its own needs
resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "order_service_pod" {
  name = "order-service-irsa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" =
            "system:serviceaccount:default:order-service"
        }
      }
    }]
  })
}
```

!!! note "Why IRSA over a node-wide IAM role"

    Without IRSA, every pod on a node inherits the node group's own IAM role — the order-service pod and any other pod scheduled on that same worker would share identical AWS permissions. IRSA scopes credentials to the individual Kubernetes service account instead, matching the least-privilege principle the customer's readiness review (cicd-delivery.html Day 22) explicitly checks for.

### 18.8 Worked Examples

Two full case studies, distinct in kind from 18.1–18.7's single-topic explainers: a complete config built and verified end to end, then that same config refactored into modules. Everything from Days 15–18 assembled into one real, applied setup — a VPC with public and private subnets, an EC2 pair reachable through *both* an ALB and an NLB. Every block in both is validated and planned against a real AWS account.

#### 18.8.1 Building It: A VPC With Both an ALB and an NLB, Story-Book Style

Built up in the order each piece actually depends on the one before it. Read it top to bottom the way it's written: why the piece exists, the code, then what it accomplished and what it unlocks next.

##### Why each piece exists, before any code

Each component below solves exactly one problem the one before it doesn't — this is the dependency chain, not the network layout (that's the next diagram).

``` mermaid
flowchart TD
    VPC["VPC<br/>Your own isolated network"] --> Subnet["Subnet<br/>A slice of that network, pinned to one AZ"]
    Subnet --> IGW["Internet Gateway<br/>The door to the internet"]
    IGW --> RT["Route Table + Route<br/>0.0.0.0/0 -> IGW is what actually makes a subnet public"]
    RT --> SG["Security Group<br/>Firewall -- explicitly allows specific traffic in"]
    SG --> AMI["AMI (data source)<br/>The OS image an instance boots from"]
    AMI --> EC2["EC2 Instance<br/>The actual server doing the work"]
    EC2 --> TG["Target Group<br/>A named, health-checked pool of backends"]
    TG --> LB["ALB / NLB<br/>The entry point -- HTTP-aware vs raw TCP passthrough"]
    LB --> Listener["Listener<br/>Opens a port, defines what to do with what arrives"]
```

*Each layer only becomes meaningful once the one above it exists — a security group rule is meaningless without a route letting traffic reach the subnet at all; a listener is meaningless without a target group to forward into.*

VPC
:   Your own private, isolated network inside AWS. Nothing else exists outside of one.

Subnet
:   A slice of the VPC's address space, pinned to one Availability Zone. "Public" vs "private" isn't inherent to the subnet — it's just which route table it ends up tied to.

Internet Gateway (IGW)
:   The door between the VPC and the internet. Without it, nothing inside the VPC can reach, or be reached from, outside AWS at all.

Route Table + Route
:   The actual switch that makes a subnet public: a `0.0.0.0/0 → IGW` route plus an association is the entire mechanism. No route table entry, no internet, regardless of anything else.

Security Group
:   The firewall. AWS denies all inbound by default — this is what explicitly allows specific traffic (port 80, from where) to reach a specific resource.

AMI (data source)
:   The OS disk image an EC2 instance boots from. Looked up live instead of hardcoded so it never goes stale.

EC2 Instance
:   The actual server doing the work — running Apache, serving `/`, `/foo`, `/bar`.

Target Group
:   A named, health-checked pool of backends. A load balancer never points at instances directly — it always points at a target group, and instances register into it separately.

ALB (Application Load Balancer)
:   Layer 7, understands HTTP (paths, headers). The entry point for web traffic.

NLB (Network Load Balancer)
:   Layer 4, raw TCP passthrough, no HTTP awareness, much higher throughput, gives static IPs. Used here as a second, independent path to the same servers.

Listener
:   Opens an actual port on a load balancer and says what to do with what arrives. Without one, the load balancer exists but accepts nothing.

##### What it looks like assembled

``` mermaid
flowchart TD
    Users(["Users"])
    Users -->|"https://.../foo<br/>https://.../bar"| ALB
    Users -->|"tcp://nlb-url"| NLB

    subgraph VPC["VPC 11.0.0.0/16 — fmk_vpc"]
        IGW["Internet Gateway<br/>fmk_igw"]
        ALB["ALB<br/>fmk_alb : 80"]
        NLB["NLB<br/>fmk_nlb : 80"]
        TGpub["Target Group<br/>fmk-tg-public (HTTP)"]
        TGpriv["Target Group<br/>fmk-tg-private (TCP)"]

        subgraph AZa["Availability Zone — ap-south-1a"]
            PubA["Public Subnet 11.0.1.0/24<br/>fmk-public-1a"]
            EC2A["EC2<br/>ec2-A"]
            PrivA["Private Subnet 11.0.3.0/24<br/>fmk-private-1a — empty"]
            PubA --- EC2A
        end

        subgraph AZb["Availability Zone — ap-south-1b"]
            PubB["Public Subnet 11.0.2.0/24<br/>fmk-public-1b"]
            EC2B["EC2<br/>ec2-B"]
            PrivB["Private Subnet 11.0.4.0/24<br/>fmk-private-1b — empty"]
            PubB --- EC2B
        end

        ALB --> TGpub
        NLB --> TGpriv
        TGpub --> EC2A
        TGpub --> EC2B
        TGpriv --> EC2A
        TGpriv --> EC2B
        PubA -. "route 0.0.0.0/0" .-> IGW
        PubB -. "route 0.0.0.0/0" .-> IGW
    end

    classDef empty fill:transparent,stroke-dasharray: 4 3,color:#888;
    class PrivA,PrivB empty;
```

*Both AZs carry a public/private pair (AZ pinning from step 3); only the public side is populated so far — the private subnets (dashed) stay empty until a database moves in.*

##### 1. Provider — connect Terraform to the account

**Why:** every resource below needs to know which AWS account and region to talk to. Nothing else in the file works without this.

``` hcl
provider "aws" {
  region  = "ap-south-1"
  profile = "fahad"
}
```

**What it did:** pointed Terraform at the `fahad` AWS CLI profile, in `ap-south-1`. **Next:** before anything can be created, it needs somewhere to live — a VPC.

##### 2. VPC — the network boundary everything else lives inside

**Why:** every subnet, load balancer, and instance below has to be created inside some VPC. `11.0.0.0/16` gives ~65,000 usable private addresses to divide up.

``` hcl
resource "aws_vpc" "fmk_vpc" {
  cidr_block = "11.0.0.0/16"
}
```

**What it did:** reserved the address range. It's still empty — no subnets, no routing, nothing launchable yet. **Next:** a VPC this size is too undifferentiated to launch into directly — it needs dividing into subnets.

##### 3. Subnets — dividing the VPC into public and private zones, across two AZs

**Why:** "public" and "private" aren't a property of the VPC as a whole — they're a property of which route table a subnet ends up associated with (steps 5/6 decide that). These four blocks carve out four non-overlapping ranges, one pair per Availability Zone: a public and a private subnet in `ap-south-1a`, a public and a private subnet in `ap-south-1b`. Pinning `availability_zone` explicitly (rather than letting AWS auto-assign one) is what guarantees a public/private pair actually shares an AZ — the pairing this diagram's two-AZ layout depends on, and the shape a database subnet group (databases.html 7.1) will need once the private subnets are actually used.

``` hcl
resource "aws_subnet" "fmk_public_1a" {
  vpc_id            = aws_vpc.fmk_vpc.id
  cidr_block        = "11.0.1.0/24"
  availability_zone = "ap-south-1a"
  tags = { Name = "fmk-public-1a" }
}

resource "aws_subnet" "fmk_public_1b" {
  vpc_id            = aws_vpc.fmk_vpc.id
  cidr_block        = "11.0.2.0/24"
  availability_zone = "ap-south-1b"
  tags = { Name = "fmk-public-1b" }
}

resource "aws_subnet" "fmk_private_1a" {
  vpc_id            = aws_vpc.fmk_vpc.id
  cidr_block        = "11.0.3.0/24"
  availability_zone = "ap-south-1a"
  tags = { Name = "fmk-private-1a" }
}

resource "aws_subnet" "fmk_private_1b" {
  vpc_id            = aws_vpc.fmk_vpc.id
  cidr_block        = "11.0.4.0/24"
  availability_zone = "ap-south-1b"
  tags = { Name = "fmk-private-1b" }
}
```

**What it did:** sliced `11.0.0.0/16` into four `/24`s, each pinned to a specific AZ — two tagged "public" and two "private," but the AZ pinning is a real constraint, not just a label. **Next:** a subnet needs a door to the internet before anything inside it is reachable from outside AWS.

!!! note "The private subnets stay empty, on purpose"

    This build only ever launches EC2 instances into the two public subnets — `fmk-private-1a`/`fmk-private-1b` exist with their own route table (step 6) but hold nothing yet. That's deliberate: they're reserved for whatever shouldn't be directly internet-reachable, most likely an RDS instance once Week 2's database patterns get revisited here. An empty subnet costs nothing to leave declared.

##### 4. Internet Gateway — the VPC's door to the internet

**Why:** a VPC is fully isolated by default. An Internet Gateway makes reaching the internet possible, but only for whichever subnets are explicitly routed through it (step 5).

``` hcl
resource "aws_internet_gateway" "fmk_igw" {
  vpc_id = aws_vpc.fmk_vpc.id
  tags   = { Name = "fmk-igw" }
}
```

**What it did:** created the gateway and attached it to `fmk_vpc` — the `vpc_id` argument itself does the attaching, no separate resource needed. **Next:** attachment alone routes no traffic. Each subnet still needs its own route table pointing at it.

##### 5. Public routing — route table, its route to the IGW, and its subnets

**Why:** this is the piece that actually makes "public" mean something. Every route table gets an in-VPC "local" route for free; adding a `0.0.0.0/0` → Internet Gateway rule, then associating a subnet with this table, is the entire mechanism that makes that subnet public. Nothing else about the subnet changes.

``` hcl
resource "aws_route_table" "fmk_public_rt" {
  vpc_id = aws_vpc.fmk_vpc.id
  tags   = { Name = "fmk-public-rt" }
}

resource "aws_route" "fmk_public_default" {
  route_table_id         = aws_route_table.fmk_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id              = aws_internet_gateway.fmk_igw.id
}

resource "aws_route_table_association" "fmk_public_1a" {
  subnet_id      = aws_subnet.fmk_public_1a.id
  route_table_id = aws_route_table.fmk_public_rt.id
}

resource "aws_route_table_association" "fmk_public_1b" {
  subnet_id      = aws_subnet.fmk_public_1b.id
  route_table_id = aws_route_table.fmk_public_rt.id
}
```

**What it did:** gave the table one rule (everything not bound for inside the VPC goes to the IGW), then associated both public subnets with it — they're now genuinely public. **Next:** the private subnets need routing too, just without that `0.0.0.0/0` rule.

##### 6. Private routing — a route table with no path to the internet

**Why:** every subnet needs an explicit association, or it silently falls back to the VPC's implicit main route table. Giving the private subnets their own table with no internet route makes "these are private" a visible, deliberate fact in the code, not an accident of what wasn't configured.

``` hcl
resource "aws_route_table" "fmk_private_rt" {
  vpc_id = aws_vpc.fmk_vpc.id
  tags   = { Name = "fmk-private-rt" }
}

resource "aws_route_table_association" "fmk_private_1a" {
  subnet_id      = aws_subnet.fmk_private_1a.id
  route_table_id = aws_route_table.fmk_private_rt.id
}

resource "aws_route_table_association" "fmk_private_1b" {
  subnet_id      = aws_subnet.fmk_private_1b.id
  route_table_id = aws_route_table.fmk_private_rt.id
}
```

**What it did:** associated both private subnets with a table that has no internet route — they keep the automatic in-VPC "local" route, so they can still reach the rest of the VPC, just never the internet directly. **Next:** the network layout is done. Now security — what's actually allowed to reach what, regardless of how traffic is routed.

##### 7. Security group — the firewall in front of the EC2 instances

**Why:** routing decides whether traffic *can* reach a subnet. A security group decides whether it's actually *allowed* to reach a specific resource, port by port. AWS denies all inbound by default — without this, the instances below would be unreachable even sitting in a public, internet-routed subnet.

``` hcl
resource "aws_security_group" "fmk_tls_sg" {
  name        = "fmk_tls_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.fmk_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.fmk_tls_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.fmk_tls_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
```

**What it did:** one group, two rules — inbound TCP 80 from anywhere (matching what Apache actually serves), and all outbound. This same group gets reused for the ALB, the NLB's targets, and the instances themselves — no separate front-door group here. **Next:** the actual compute, and the AMI it boots from.

##### 8. AMI lookup — which OS image the instances boot from

**Why:** an instance needs an AMI to boot from. Querying for "whichever Amazon Linux 2023 AMI is newest right now" instead of hardcoding an ID avoids that ID going stale the moment AWS ships a patched version.

``` hcl
data "aws_ami" "amzn_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
```

**What it did:** nothing created — `data` blocks only read (15.3). This resolves to today's latest Amazon Linux 2023 AMI ID for `ap-south-1` at plan/apply time. **Next:** the EC2 instances themselves.

##### 9. EC2 instances — the actual servers

**Why:** the real compute — two servers that will sit behind both load balancers. Each launches into a different public subnet so the pair survives a single AZ failure.

``` hcl
resource "aws_instance" "ec2-A" {
  ami                    = data.aws_ami.amzn_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.fmk_public_1a.id
  user_data              = file("${path.module}/userdata.sh")
  vpc_security_group_ids = [aws_security_group.fmk_tls_sg.id]
  tags                   = { Name = "fmk-ec2-A" }
}

resource "aws_instance" "ec2-B" {
  ami                    = data.aws_ami.amzn_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.fmk_public_1b.id
  user_data              = file("${path.module}/userdata.sh")
  vpc_security_group_ids = [aws_security_group.fmk_tls_sg.id]
  tags                   = { Name = "fmk-ec2-B" }
}
```

**What it did:** launched both instances, each bootstrapped by `userdata.sh` (installs Apache, writes `/`, `/foo`, and `/bar` pages showing that instance's own hostname and IP), each attached to `fmk_tls_sg` so port 80 can actually reach them. **Next:** the servers are individually reachable if you knew their IPs — but nothing distributes traffic across the two yet. That's the ALB's job first.

!!! danger "user_data has to match the AMI family, not just the SSH user"

    16.7 already covers the wrong-SSH-user version of this mistake (`ubuntu` vs `ec2-user`) — the same AMI-dependence bites the *script itself*, not just the login. A real `user_data` script written with `apt-get update` / `apt-get install -y apache2` against this exact `al2023-...` AMI failed completely: Amazon Linux has no `apt-get` at all (it uses `dnf`/`yum`), so the very first line errors with `command not found` and nothing after it ever runs. Even fixed to the right package manager, the package name is also OS-specific — Amazon Linux's Apache is called `httpd`, never `apache2` (that's Debian/Ubuntu's name for the same thing). Matching `userdata.sh`'s commands to the actual AMI family is exactly as necessary as matching the SSH username to it.

!!! success "Check /var/log/cloud-init-output.log before rewriting blind"

    A failed `user_data` script gives no error anywhere in `terraform apply` — the instance still reaches `running` either way, since AWS considers the instance successfully launched regardless of what its boot script did. The only place the actual failure (`apt-get: command not found`, in this case) shows up is `/var/log/cloud-init-output.log` on the instance itself, over SSH — worth checking directly rather than guessing at what a silent script failure was.

##### 10. ALB path — target group, then the ALB, then its listener

**Why a target group first:** an ALB never points at instances directly — a target group is the indirection layer in between, a named, health-checked pool the ALB forwards to. Declaring the group and its membership separately from the ALB means instances can be added or removed without touching the ALB at all.

``` hcl
resource "aws_lb_target_group" "fmk-tg-public" {
  name        = "fmk-tg-public-1a"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.fmk_vpc.id
}

resource "aws_lb_target_group_attachment" "ec2_a" {
  target_group_arn = aws_lb_target_group.fmk-tg-public.arn
  target_id         = aws_instance.ec2-A.id
  port              = 80
}

resource "aws_lb_target_group_attachment" "ec2_b" {
  target_group_arn = aws_lb_target_group.fmk-tg-public.arn
  target_id         = aws_instance.ec2-B.id
  port              = 80
}
```

**Why the ALB:** the actual internet-facing entry point — what a browser connects to. It needs the public subnets (to be internet-reachable) and the security group governing what can reach it.

``` hcl
resource "aws_alb" "fmk_alb" {
  name               = "fmk-alb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.fmk_tls_sg.id]
  subnets            = [aws_subnet.fmk_public_1a.id, aws_subnet.fmk_public_1b.id]
}
```

**Why the listener:** this is what actually opens a port on the ALB and defines what to do with what arrives on it — without one, the ALB accepts nothing and every connection times out.

``` hcl
resource "aws_lb_listener" "fmk_alb_http" {
  load_balancer_arn = aws_alb.fmk_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fmk-tg-public.arn
  }
}
```

**What it did:** opened port 80 on the ALB, forwarding everything into `fmk-tg-public`. The ALB path is complete: internet → ALB:80 → `fmk-tg-public` → `ec2-A`/`ec2-B`. No separate listener rules for `/foo`/`/bar` are needed — both instances already serve those paths themselves (`userdata.sh`), so one forward action reaches either path on whichever instance the ALB picks. **Next:** the second path — the same instances, reached through an NLB instead.

##### 11. NLB path — a second target group, the NLB, and its listener

**Why a second target group:** an ALB target group and an NLB target group aren't interchangeable — this one is TCP, matching what an NLB actually forwards (raw connections, no HTTP awareness at all). The same two instances register here too — one pool of servers, reachable through two independent paths, not two separate pools.

``` hcl
resource "aws_lb_target_group" "fmk-tg-private" {
  name     = "fmk-tg-private-1a"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.fmk_vpc.id
}

resource "aws_lb_target_group_attachment" "ec2_a_nlb" {
  target_group_arn = aws_lb_target_group.fmk-tg-private.arn
  target_id         = aws_instance.ec2-A.id
  port              = 80
}

resource "aws_lb_target_group_attachment" "ec2_b_nlb" {
  target_group_arn = aws_lb_target_group.fmk-tg-private.arn
  target_id         = aws_instance.ec2-B.id
  port              = 80
}
```

**Why the NLB:** the same role as the ALB — the entry point — but Layer 4 instead of Layer 7. Notice there's no `security_groups` argument: an NLB has no security group of its own, being pure passthrough. Access control for this path lives entirely on the target's own SG (`fmk_tls_sg`, step 7), which is why that rule had to allow `0.0.0.0/0` rather than being scoped to one specific load balancer.

``` hcl
resource "aws_lb" "fmk_nlb" {
  name               = "fmk-nlb-tf"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.fmk_public_1a.id, aws_subnet.fmk_public_1b.id]
}

resource "aws_lb_listener" "fmk_nlb_tcp" {
  load_balancer_arn = aws_lb.fmk_nlb.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fmk-tg-private.arn
  }
}
```

**What it did:** opened port 80 on the NLB, forwarding every raw TCP connection into `fmk-tg-private`. Both paths are now complete: internet → ALB:80 → `fmk-tg-public` → the instances, and internet → NLB:80 → `fmk-tg-private` → the same instances.

!!! success "Verified, not just written"

    This exact config — 28 resources — ran clean through `terraform validate` and `terraform plan` against a real AWS account with zero errors. Building it surfaced real mistakes worth recognizing on sight: a `security_groups` argument pointed at rule resources instead of the group itself, a missing `subnets` argument on an ALB, an underscore in a load-balancer name (AWS only allows hyphens), a security group rule scoped to 443/VPC-only when the app actually serves 80 to the internet, a `target_type` of `"alb"` left over on a target group meant to hold EC2 instances, and two EC2 instances launched with no security group attached at all — each one invisible until either `validate` caught it structurally, or reasoning through what the diagram actually required caught it semantically.

#### 18.8.2 The Same 28 Resources, Refactored Into Modules

18.8.1's single `main.tf` pulled apart into four modules — `network`, `security`, `compute`, `loadbalancing` — following exactly the module-design principles from 16.4/16.6. Worth being honest about the trade-off up front: 16.6's own "rule of three" says don't extract a module until something's genuinely reused a third time, and this only has one caller. Doing it anyway here is a deliberate learning exercise — practicing the shape of a real module before there's a second environment forcing the issue — not a case where the rule stopped applying.

``` text
day02-modules/
├── versions.tf      -- Terraform + provider version constraints
├── variables.tf     -- root inputs: region, profile, vpc_cidr, name_prefix
├── main.tf          -- four `module` calls, wiring outputs into inputs. No resource blocks.
├── outputs.tf       -- vpc_id, alb_dns_name, nlb_dns_name
└── modules/
    ├── network/        (VPC, 4 subnets, IGW, both route tables)
    ├── security/        (the shared security group + its two rules)
    ├── compute/         (AMI lookup, EC2 instances, userdata.sh)
    └── loadbalancing/   (both target groups, ALB, NLB, both listeners)
        each containing: versions.tf, variables.tf, main.tf, outputs.tf
```

##### What each file type holds, and why it's separate

`versions.tf`
:   Terraform and provider version constraints (15.2) — nothing here creates anything, it's checked once at `init`. Every module carries its own copy: a module should be explicit about what it needs regardless of what the root happens to declare, so it stays correct if it's ever pulled into a different project.

`variables.tf`
:   The module's inputs — its public interface (16.4). Reading this file alone should tell you everything needed to call the module, without opening `main.tf` at all. `modules/security/variables.tf`, for example, says "give me a `vpc_id`; I'll assume port 80 unless you override `ingress_port`."

`main.tf`
:   The actual `resource`/`data` blocks — the implementation. A caller never needs to read this; it's free to change internally as long as `variables.tf` and `outputs.tf` stay the same contract.

`outputs.tf`
:   The module's return values — whatever the next module in the chain needs back. `modules/network/outputs.tf` hands back `vpc_id` and both subnet maps because `security`, `compute`, and `loadbalancing` all need those downstream.

!!! note "Root main.tf contains zero resource blocks"

    Once split, the root `main.tf` is just four `module` calls passing outputs forward — `module.network.vpc_id` into `security`, both of those into `compute`, all three into `loadbalancing`. Every actual `resource` lives one level down, inside a module. This is what "the root just wires things together" looks like in a real file, not just as a description.

##### One resource, before and after

Splitting into modules was also a chance to apply 16.1's `for_each` guidance retroactively. 18.8.1's four separately-named subnet resources became one `for_each` block over a map:

``` hcl
## Before (18.8.1) -- four separate resources
resource "aws_subnet" "fmk_public_1a" { cidr_block = "11.0.1.0/24" ... }
resource "aws_subnet" "fmk_public_1b" { cidr_block = "11.0.2.0/24" ... }
# state addresses: aws_subnet.fmk_public_1a, aws_subnet.fmk_public_1b

## After (day02-modules) -- one resource, driven by the caller's map
resource "aws_subnet" "public" {
  for_each          = var.public_subnets
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone
}
# state addresses: module.network.aws_subnet.public["1a"], ["1b"]
```

Same two subnets get created either way — `terraform plan` on the modularized version still shows **28 to add, 0 to change, 0 to destroy**, identical to 18.8.1. What changed is that adding a third AZ later means adding one entry to the `public_subnets` map passed into the module, not writing a fifth resource block by hand.

### 18.9 AWS Lambda: IAM, Packaging & the S3 Deployment Pattern

A Lambda function needs three things before it can run at all: an IAM role it assumes, permission to actually write logs, and its code packaged into a deployment artifact. None of these are optional — skip the role and the function has no identity to run as; skip the logging permission and it runs but you can never see why it failed.

``` hcl
# 1. The role Lambda itself assumes when invoking the function
resource "aws_iam_role" "lambda_role" {
  name = "tf-aws-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# 2. What that role is actually allowed to do -- here, just write logs
resource "aws_iam_policy" "iam_policy_for_lambda" {
  name = "aws_iam_policy_for_tf_aws_lambda_role"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "arn:aws:logs:*:*:*"
      Effect   = "Allow"
    }]
  })
}

# 3. Attach the policy to the role -- two separate resources, same pattern as
#    every other IAM role+policy pairing (16.4's "declare the parent, then the membership")
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}

# 4. Zip the function code -- a data source, not a resource: it reads
#    local files and produces an archive, it doesn't create anything in AWS
data "archive_file" "zip_the_lambda_code" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda/lambda-func.zip"
}

# 5. The function itself, uploaded directly
resource "aws_lambda_function" "tf_lambda_func" {
  filename      = data.archive_file.zip_the_lambda_code.output_path
  function_name = "fmk-tf-lambda-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.10"
  depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_role]
}
```

!!! note "jsonencode() over a raw heredoc"

    Both work, but `jsonencode({...})` builds the JSON from real HCL values — Terraform catches a typo'd key or a missing comma at `plan` time, the same way `validation` blocks (16.4) catch mistakes before `apply` does. A policy document written as a `<<EOF` heredoc string is just text as far as Terraform's concerned — a malformed JSON heredoc doesn't fail until AWS itself rejects the policy.

!!! success "depends_on earns its place here"

    Nothing about `aws_lambda_function` references the policy attachment directly, so Terraform can't infer the ordering from a value reference (15.3) the way it does for `role = aws_iam_role.lambda_role.arn`. Without the explicit `depends_on`, the function could attempt to create before the role actually has its logging permission attached, and either fail outright or succeed with a role that briefly can't write logs.

#### Large functions: deploying from S3 instead of a direct upload

`filename` above uploads the zip directly as part of the `CreateFunction`/`UpdateFunctionCode` API call. That has a hard ceiling: AWS caps a **direct** deployment package at 50 MB zipped. Past that, or as a matter of course in most real pipelines regardless of size, the function's code is uploaded to S3 first, and the Lambda resource just points at where it landed:

``` hcl
resource "aws_s3_object" "lambda_package" {
  bucket = "fmk-lambda-deployments"
  key    = "tf-aws-lambda/lambda-func.zip"
  source = data.archive_file.zip_the_lambda_code.output_path
  etag   = data.archive_file.zip_the_lambda_code.output_md5
}

resource "aws_lambda_function" "tf_lambda_func" {
  s3_bucket     = aws_s3_object.lambda_package.bucket
  s3_key        = aws_s3_object.lambda_package.key
  function_name = "fmk-tf-lambda-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.10"
  depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_role]
}
```

!!! success "Why real pipelines use this even under 50 MB"

    Beyond the size ceiling, S3-based deployment means the artifact exists as a named, addressable object — a CI pipeline can build the zip once, upload it, and reference the exact same S3 object from multiple environments (dev/stg/prod) without re-zipping or re-uploading. `etag = data.archive_file...output_md5` is what makes Terraform notice the code actually changed: without it, updating the local zip wouldn't trigger a new `aws_s3_object` upload at all, and the function would silently keep running the old code.

!!! danger "250 MB unzipped is still a hard ceiling either way"

    S3-based deployment raises the limit, it doesn't remove it — AWS caps the *unzipped* deployment package (code plus every dependency) at 250 MB regardless of upload method. A function approaching that size is usually a sign it's bundling more than it needs (16.6's over-abstraction warning, applied to a dependency tree instead of a module) — worth checking whether a Lambda Layer, or splitting into more than one function, fits better than pushing the ceiling.

### 18.10 Provisioning a Jenkins Controller

A Jenkins controller (jenkins.html) is itself just a resource — an EC2 instance, a security group, and a `user_data` script that installs and starts it, the same shape as every other compute resource in this file.

``` bash
#!/bin/bash
dnf update -y
dnf install -y java-17-amazon-corretto
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins
systemctl enable --now jenkins
```

!!! note "dnf, not apt-get — same lesson as 18.8.1"

    This script assumes an Amazon Linux AMI, matching the exact AMI-family reasoning already covered for `user_data` scripts in general: the package manager and package names have to match the actual OS the instance boots from, not whatever was copied from a different example.

``` hcl
resource "aws_ebs_volume" "jenkins_home" {
  availability_zone = aws_instance.jenkins_controller.availability_zone
  size              = 50
  tags              = { Name = "jenkins-home" }
}

resource "aws_volume_attachment" "jenkins_home" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.jenkins_home.id
  instance_id = aws_instance.jenkins_controller.id
}
```

!!! danger "JENKINS_HOME does not belong on the root volume"

    Every job config, build history, and credential Jenkins holds lives under `JENKINS_HOME` (`/var/lib/jenkins` by default). Mounting it on a separate EBS volume, not the instance's root volume, means replacing the controller instance itself — a new AMI, a resize, a region move — doesn't threaten that data at all: detach the volume, attach it to the new instance, done. Same principle as 19.7's `prevent_destroy` on a critical resource — the data that actually matters shouldn't share a lifecycle with the compute that happens to be running it this week.


## 19 Operating Terraform, Checkpoint 2

Keeping state healthy once real changes start landing, then the checkpoint.

### 19.1 Drift Detection

Drift is state disagreeing with reality — someone widened a security group rule in the console during an incident, or an ASG's `desired_capacity` moved because a scaling policy fired (17.1 introduced the concept; this is catching it in practice).

``` bash
# Refresh Terraform's view of reality and show any drift, without touching anything
terraform plan -refresh-only

# Older/equivalent: refresh state, then a normal plan will show the same drift
terraform apply -refresh-only
```

``` text
  # aws_security_group.app has changed
  ~ resource "aws_security_group" "app" {
      ~ ingress = [
          + {
              + cidr_blocks = ["0.0.0.0/0"]
              + from_port   = 22
              + to_port     = 22
              + protocol    = "tcp"
            },
        ]
    }

This is a refresh-only plan, so Terraform will not take any actions.
```

!!! success "Schedule it, don't wait to trip over it"

    A weekly `plan -refresh-only` run in CI, posting its output somewhere visible, catches console-made changes within a week instead of at the next unrelated `apply`, when the drifted resource shows up mixed in with changes nobody intended to make.

!!! danger "Detecting drift isn't fixing it"

    `-refresh-only` only updates what Terraform believes state to be — it does not push your config back onto AWS, and it does not pull the drifted value into your `.tf` files either. Deciding whether the *console change* or the *code* is correct is still a human call every time.

### 19.2 Targeted Apply, and When It's a Mistake

``` bash
# Apply changes to just this one resource, ignoring other pending diffs
terraform apply -target=aws_launch_template.app
```

!!! success "Legitimate use: an emergency, isolated fix"

    Production is down because of one resource, the fix is known, and a full `plan` right now would also apply three unrelated in-flight changes nobody's reviewed yet. `-target` applies only the fix.

!!! danger "The mistake: using it as a habit"

    Repeated `-target` applies let a config and its state quietly drift apart from each other in a different way than 19.1 — not AWS vs. state, but "the parts of config that get applied" vs. "the parts that don't." The next full, untargeted `apply` can produce a surprisingly large plan, because everything skipped over every targeted run finally shows up at once. Terraform itself warns about this every time `-target` is used — treat that warning as accurate, not boilerplate.

### 19.3 `moved` Blocks

Renaming a resource in code, or moving it into a module, changes its address (`aws_instance.app` → `module.compute.aws_instance.app`). Terraform matches state by address, not by intent — without help, it reads that as "the old one was deleted, a new one must be created," and plans a destroy-and-recreate of something that never actually changed on AWS.

``` hcl
# after moving aws_instance.app into a module, add this alongside it
moved {
  from = aws_instance.app
  to   = module.compute.aws_instance.app
}
```

``` text
$ terraform plan
Note: Objects have changed outside of Terraform

  # aws_instance.app has moved to module.compute.aws_instance.app
    resource "aws_instance" "app" {
        id = "i-0aaa1111aaaa11111"
    }

No changes. Your infrastructure matches the configuration.
```

!!! success "This is exactly what 16.6's repo layout refactor needs"

    Extracting an inline resource into a module — the "third time" moment from 16.6's rule of three — is precisely when a `moved` block matters: it lets the refactor be a no-op against real infrastructure, instead of an accidental destroy-and-recreate of something already running in production.

!!! danger "This happened for real, on this exact mistake"

    Switching an `aws_iam_user` resource from `count` to `for_each` — without a `moved` block — produced a plan reading `Plan: 4 to add, 0 to change, 3 to destroy`. Typing `yes` anyway destroyed three real IAM users, then failed to recreate two of them (a race between the parallel destroy and create for the same username). The fix was mechanical, not scary: since the destroyed users genuinely no longer existed, a follow-up `apply` recreated them cleanly with no conflict. The lesson is the plan line itself — `count` → `for_each` always shows as unrelated destroy+create unless a `moved` block (or `state mv`, 19.4) tells Terraform the two addresses are the same object — and "3 to destroy" in a plan is worth stopping on every single time, not just reading past.

### 19.4 `state mv` and `state rm`

`moved` blocks (19.3) are the modern, declarative way to record a rename — they live in code and survive a fresh checkout. `terraform state mv` does the same rewrite imperatively, once, from the CLI — useful when you need it done immediately and won't remember (or won't bother) to leave a `moved` block behind.

``` bash
# Same effect as the moved block in 19.3, done directly against the state file
terraform state mv aws_instance.app module.compute.aws_instance.app

# Remove a resource from Terraform's management without destroying it in AWS --
# for handing a resource off to another team's config, or before a manual takeover
terraform state rm aws_instance.legacy_bastion

# List what's actually in state right now
terraform state list
```

!!! danger "`state rm` doesn't delete anything in AWS"

    It only removes the resource from Terraform's bookkeeping — the real EC2 instance keeps running, untouched. The easy mistake is expecting `state rm` to be a lightweight `destroy`; it's the opposite, a way to stop managing something while leaving it exactly as it is.

### 19.5 Recovering a Half-Applied State

An `apply` can be interrupted mid-run — a killed terminal, a lost network connection, a lock timeout — after some resources succeeded and before others did. State reflects whatever finished before the interruption; nothing about it is inherently corrupt, but it needs deliberate steps to get back to normal, not blind re-running.

``` bash
# 1. If a lock was left behind by the interrupted run, confirm nothing else is actually applying, then:
terraform force-unlock <LOCK_ID>

# 2. Reconcile state with what's actually on AWS before touching anything else
terraform plan -refresh-only

# 3. A normal plan now shows only the resources still pending from the interrupted apply --
#    read it like any other plan before applying
terraform plan
terraform apply
```

!!! danger "force-unlock is a last resort, not a first reaction"

    Run it while the original process might still be applying, and two applies now race against the same state with no lock protecting either — the exact failure mode locking (17.2) exists to prevent. Confirm the original process is actually dead (check who holds the lock, ask the team) before force-unlocking.

!!! success "Half-applied is recoverable precisely because state is incremental"

    Each resource is recorded as it succeeds, not all-or-nothing at the end — that's why `plan` after an interruption shows only what's left to do, rather than an all-or-nothing do-over of the entire config.

### 19.6 Machine-Readable Plans for Automation

The human-readable plan output from 15.5 is for a person reading a terminal. A CI pipeline (Week 5) needs to act on a plan programmatically — post it as a PR comment, gate an approval on whether anything destructive is in it — which means parsing it as structured data instead of text.

``` bash
# Save the plan to a binary file, then export it as JSON
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json

# Pull out just the destructive actions -- exactly the check Week 5's
# approval gate runs before anyone clicks "approve"
jq '.resource_changes[] | select(.change.actions | index("delete"))' tfplan.json
```

!!! note "Why -out matters here"

    `terraform show -json` without a saved plan file re-runs `plan` against current state — which can differ from the plan a human or a pipeline already reviewed, if anything changed in between. Saving with `-out` and applying that exact file (`terraform apply tfplan.binary`) guarantees the plan that was reviewed is the plan that gets applied, with nothing able to slip in between the two.

!!! success "This is the actual mechanism behind Week 5's PR gate"

    "terraform plan posted as a comment" and "the approval gate" (cicd-delivery.html Day 21) are both built on exactly this JSON output — a script reads `tfplan.json`, formats a summary, and posts it; the approval step re-checks it for anything destructive before allowing `apply` to run the saved `tfplan.binary`.

### 19.7 Importing Existing Resources

Something created by hand in the console — or by anyone else, outside Terraform entirely — has no entry in state. Terraform doesn't know it exists, so `plan`/`apply` assumes it needs to be created, and AWS rejects the create because the real thing is already there:

``` text
│ Error: creating IAM User (nsl-media-vault-app-s3-access): operation error IAM: CreateUser,
│ https response error StatusCode: 409, EntityAlreadyExists: User with name
│ nsl-media-vault-app-s3-access already exists.
```

`terraform import` fixes this — and only this. It does not create, modify, or delete anything in AWS; it just writes an entry into the state file saying "this resource address already corresponds to this real object."

``` bash
# Syntax: terraform import <resource address> <the resource's real ID>
terraform import 'aws_iam_user.example["nsl-media-vault-app-s3-access"]' nsl-media-vault-app-s3-access
```

!!! note "The ID on the right isn't universal"

    What counts as "the ID" is resource-type-specific — for `aws_iam_user` it's the username, for `aws_instance` it's the instance ID (`i-0aaa1111aaaa11111`), for `aws_s3_bucket` it's the bucket name. Always check the specific resource's page on the [Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) — it documents the exact import ID format, usually right at the bottom of the page.

After importing, run `plan` — it should show **0 to change** if your config's arguments already match the real object's actual settings. If they don't match, `plan` shows exactly what it would change to bring the real object in line with your code — read that like any other plan before applying.

!!! danger "Importing into a count index is fragile"

    Importing into `aws_iam_user.example[3]` ties the import to a *position* in a list (16.1's gotcha, again). If that list ever reorders, index `3` can silently point at a different resource next `apply`. Importing into a `for_each`-keyed address instead — `aws_iam_user.example["nsl-media-vault-app-s3-access"]`, as above — ties the import to a stable name that can't shift underneath it.

#### Worked example: importing a resource that must never be destroyed

Bringing a genuinely important resource under Terraform's control — a long-running production instance, not a throwaway learning one — deserves an extra step before anything else touches it.

``` hcl
resource "aws_instance" "critical_app" {
  ami           = "ami-0333333333333333"
  instance_type = "t3.micro"

  tags = {
    Name = "critical-app"
  }

  lifecycle {
    prevent_destroy = true   # add this in the same edit as the import, not after
  }
}
```

``` bash
terraform import aws_instance.critical_app i-0aaa1111aaaa11111
terraform plan   # confirm 0 to change, or read exactly what doesn't match yet
```

With `prevent_destroy` already in place, a routine, safe change — updating tags, say — applies normally:

``` text
  # aws_instance.critical_app will be updated in-place
  ~ resource "aws_instance" "critical_app" {
        id   = "i-0aaa1111aaaa11111"
      ~ tags = {
            "Name"  = "critical-app"
          + "Owner" = "fahad"
        }
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

!!! success "prevent_destroy is the actual safety net here"

    Before this instance was imported, nothing about it could be "destroyed by Terraform" — Terraform didn't know it existed. The moment it's imported, that protection disappears unless something replaces it — which is exactly `prevent_destroy`'s job. Add it in the *same* edit as the import itself, not as a follow-up step: any change that would force replacement (18.8.1's `-/+` from 15.5) now fails outright with an error instead of silently destroying and recreating a resource that was never meant to be disposable.

### 19.8 Debug Logging: TF_LOG and TF_LOG_PATH

When a plan or apply fails with an error too vague to act on, Terraform's own internal logging — normally silent — can be turned on to see exactly what it's doing: every provider RPC call, every HTTP request to AWS, every internal decision.

``` bash
export TF_LOG=DEBUG          # TRACE, DEBUG, INFO, WARN, or ERROR -- TRACE is the noisiest
terraform plan

# unset when done -- it stays exported for every future command in this shell otherwise
unset TF_LOG
```

!!! note "TRACE vs DEBUG"

    `TRACE` is the most verbose level — it includes the exact HTTP requests and responses between the provider and AWS's API, useful for tracking down a provider bug or an unexpected API response. `DEBUG` is one level down: Terraform's own internal decisions and provider RPC calls, usually enough for "why did it plan to do that" without the sheer volume of raw HTTP traffic.

Left on, `TF_LOG` prints directly to the terminal, mixed in with normal plan/apply output — usable for a quick look, unmanageable for anything longer. `TF_LOG_PATH` redirects it to a file instead:

``` bash
export TF_LOG=DEBUG
export TF_LOG_PATH="/home/fahad/logs/debug.log"
terraform apply
```

!!! danger "The directory has to already exist"

    Terraform does not create missing directories in `TF_LOG_PATH` — pointing it at `/home/fahad/logs/debug.log` when `/home/fahad/logs/` doesn't exist yet fails to write the log at all (checked directly: a fresh `logs/` directory genuinely doesn't exist until something creates it). `mkdir -p` the directory first, the same requirement as any other tool writing to a path you haven't set up yet.

!!! note "The log file is appended to, not overwritten"

    Every subsequent command with the same `TF_LOG_PATH` set keeps adding to the same file rather than starting fresh — a log from an hour ago and one from just now sit in the same file, back to back. Delete or rotate it manually between debugging sessions, or it grows indefinitely and makes finding the relevant run harder each time.

!!! success "Unset both when done"

    Both variables persist for every Terraform command run in that shell session afterward, not just the one that needed debugging — exactly the same "stray environment variable" class of surprise as 15.2's credential-precedence gotcha. A stray `TF_LOG=TRACE` left set makes every future `plan` print pages of noise nobody asked for; `unset TF_LOG TF_LOG_PATH` (or just open a fresh terminal) once the debugging is done avoids that.

### 19.9 Beyond the Checkpoint: Terraform Associate Certification

An external, formal validation of everything Week 4 covers — HashiCorp's own [Terraform Associate (004)](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-review-004) exam, current as of late 2026 (the prior 003 version retired January 2026).

|  |  |
|---|---|
| Format | 1 hour, online proctored, ~57 questions (multiple choice / multiple answer / true-false) |
| Cost | ~$70.50 USD + local taxes |
| Validity | 2 years |
| Prerequisites | None |
| Tests against | Terraform 1.12 |

#### The 8 official objectives

1. **Infrastructure as Code with Terraform** — what IaC is, its advantages, multi-cloud/hybrid/service-agnostic workflows
2. **Terraform Fundamentals** — installing/versioning providers, multi-provider configs, how state is used (15.2, 17.1)
3. **Core Terraform Workflow** — `init`, `validate`, `plan`, `apply`, `destroy`, `fmt` (15.4, 15.5)
4. **Terraform Configuration** — `resource` vs `data`, cross-resource references, variables/outputs, complex types, expressions/functions, resource dependencies, custom validation conditions, sensitive data handling including Vault (15.3, 15.6, 16.1, 16.4, 16.10)
5. **Terraform Modules** — sourcing, variable scope, using, versioning (16.4, 16.5, 16.6, 18.8.2)
6. **Terraform State Management** — local backend, state locking, remote state via `backend`, drift (17.1, 17.2, 19.1)
7. **Maintain Infrastructure with Terraform** — `import`, inspecting state via the CLI, verbose logging (19.4, 19.7, 19.8)
8. **HCP Terraform** — creating infrastructure via HCP Terraform, collaboration/governance features, workspaces/projects, integrations

!!! success "Objectives 1–7: already in strong shape"

    Every objective above except the last has a real, hands-on match somewhere in this week — not just reading about the concept, but having hit its actual failure modes against a real account (drift, a corrupted lock, a botched import, a missing `depends_on`). That's a meaningfully stronger position than most exam preparation, which is usually reading-only.

!!! danger "Objective 8 (HCP Terraform) is the one clean gap"

    Nothing in this project has touched HCP Terraform specifically — its workspaces/projects, collaboration and governance features, or run-integration model. That's roughly one-eighth of the exam, covering a genuinely different product surface (a hosted service, not the CLI/provider mechanics everything else here is built on) — worth deliberate, separate study before sitting the exam, rather than assuming it's covered by the remote-backend/state concepts already learned.

!!! note "Checkpoint 2"

    Given a diagram, produce working, readable, reproducible code inside the session, and perform state operations without notes — then hand over the repository.


