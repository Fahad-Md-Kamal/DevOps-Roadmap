#!/bin/bash
# Note: The script runs as root, so sudo is not strictly required.
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

PRIVATE_IP=$(hostname -I | cut -d' ' -f1)
SERVER_NAME=$(hostname)

echo "<h1>Hello World from EC2 bootstrapped by Terraform</h1><p><strong>Hostname:</strong> $SERVER_NAME</p><p><strong>Private IP:</strong> $PRIVATE_IP</p>" > /var/www/html/index.html

mkdir -p /var/www/html/foo
echo "<h1>Hello from /foo</h1><p><strong>Hostname:</strong> $SERVER_NAME</p><p><strong>Private IP:</strong> $PRIVATE_IP</p>" > /var/www/html/foo/index.html

mkdir -p /var/www/html/bar
echo "<h1>Hello from /bar</h1><p><strong>Hostname:</strong> $SERVER_NAME</p><p><strong>Private IP:</strong> $PRIVATE_IP</p>" > /var/www/html/bar/index.html
