# Ansible practice lab

Local-only practice environment for [docs/ansible.md](../docs/ansible.md)'s §23.3 roadmap. Two Docker containers (`ansible-node1`, `ansible-node2`) stand in for managed nodes — no AWS cost, rebuildable in seconds.

## First-time setup (already done once)

```bash
python3 -m venv .venv && source .venv/bin/activate && pip install ansible
docker build -t ansible-practice-node -f docker/Dockerfile.node docker/
docker run -d --name ansible-node1 -p 2221:22 ansible-practice-node
docker run -d --name ansible-node2 -p 2222:22 ansible-practice-node
```

## Each new session

```bash
source .venv/bin/activate
docker start ansible-node1 ansible-node2   # if the containers were stopped
ansible web -m ping | cat
```

!!! Known gotcha: `ERROR: Ansible requires blocking IO on stdin/stdout/stderr`

This Claude Code harness's shell leaves stdout/stderr non-blocking, which Ansible
explicitly refuses to run under. Piping any `ansible`/`ansible-playbook` command
through `| cat` forces blocking I/O and fixes it — not needed in a normal terminal,
only in this harness.

## Tearing it down

```bash
docker rm -f ansible-node1 ansible-node2
docker rmi ansible-practice-node
```

Nothing here touches real AWS resources — `inventory.ini` points at `127.0.0.1` on
mapped container ports only.
