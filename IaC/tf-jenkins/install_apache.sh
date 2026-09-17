#!/bin/bash
sudo yum update -y
sudo yum install -y java-21-amazon-corretto git docker
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
