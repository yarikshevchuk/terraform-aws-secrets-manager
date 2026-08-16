#!/bin/bash
sudo apt update && sudo apt install -y curl unzip

# The official AWS CLI v2 installer
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"


unzip awscliv2.zip
sudo ./aws/install

# Cleanup
rm -rf awscliv2.zip aws
