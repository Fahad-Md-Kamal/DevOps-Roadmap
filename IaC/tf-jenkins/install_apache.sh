#!/bin/bash
sudo yum update -y

# Java -- required by Jenkins' own agent (remoting.jar)
# Git -- required to clone the repo in the "Code" stage
# Docker -- required to build/run the app's image
sudo yum install -y java-21-amazon-corretto git docker

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
