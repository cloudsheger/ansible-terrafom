#!/bin/bash

# Machine-specific configurations to customize the workstation from the AMI.
useradd -m -G adm,docker,wheel,maintuser -c "${user_name}" ${user_name}
mkdir -m 0700 /home/${user_name}/.ssh
echo "${public_key}" > /home/${user_name}/.ssh/authorized_keys
chmod 0600 /home/${user_name}/.ssh/authorized_keys
chown -R ${user_name}:${user_name} /home/${user_name}/.ssh

echo "# User rules for ${user_name}
${user_name} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/ztpt-users
chmod 0440 /etc/sudoers.d/ztpt-users

PYPI_URL=https://pypi.org/simple

# Setup terminal support for UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Ensure pip exists
python3 -m ensurepip

# Upgrade python build dependencies
python3 -m pip install --index-url="$PYPI_URL" --upgrade pip setuptools

# Install watchmaker
python3 -m pip install --index-url="$PYPI_URL" --upgrade watchmaker boto3

# execute watchmaker
#watchmaker -e <environment> -A <admin_group> -t <computer_name> --log-dir=/var/log/watchmaker -c s3://dicelab-watchmaker/config.yaml
