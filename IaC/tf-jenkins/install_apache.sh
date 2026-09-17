#!/bin/bash
sudo yum update -y

# Java -- required by Jenkins' own agent (remoting.jar)
# Git -- required to clone the repo in the "Code" stage
# Docker -- required to build/run the app's image
# make -- not on the base AL2023 image; required to run the app's Makefile
# targets (`make start`, etc.) from the pipeline
sudo yum install -y java-21-amazon-corretto git docker make

# Node.js/npm -- required to build the frontend. Installed from NodeSource's
# own yum repo rather than nvm: nvm only wires itself into an *interactive*
# login shell (~/.bashrc), which Jenkins' non-interactive SSH-launched shell
# never sources -- a repo-installed package lands on the system PATH for
# every user and every shell type instead.
# curl -fsSL https://rpm.nodesource.com/setup_24.x | sudo bash -
# sudo yum install -y nodejs

# Start Docker now and on every boot, and let ec2-user run docker without
# sudo -- required before the agent ever connects, since group membership
# is fixed when a process starts and won't apply retroactively to an
# already-running Jenkins agent process.
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user

# Docker Compose (v2, the "docker compose" plugin) -- Amazon Linux 2023 has
# no native yum package for it, so install the CLI plugin binary directly,
# same as Docker's own documented install path for distros without one.
sudo mkdir -p /usr/libexec/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/libexec/docker/cli-plugins/docker-compose
sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# Docker Buildx -- `docker compose build` requires it (0.17.0+) even when
# nothing in the compose file asks for BuildKit features explicitly; without
# it, "compose build" fails outright with "requires buildx 0.17.0 or later".
# Buildx's release asset name embeds its version, so resolve the latest tag
# via the GitHub API first rather than guessing a version number.
BUILDX_VERSION=$(curl -s https://api.github.com/repos/docker/buildx/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
sudo curl -SL "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-amd64" \
  -o /usr/libexec/docker/cli-plugins/docker-buildx
sudo chmod +x /usr/libexec/docker/cli-plugins/docker-buildx
