#!/bin/bash

# Create a new user and add them to relevant groups
useradd -m -G adm,wheel,maintuser -c "${user_name}" "${user_name}"

# Create the user's .ssh directory and set appropriate permissions
mkdir -p "/home/${user_name}/.ssh"
chmod 0700 "/home/${user_name}/.ssh"

# Add the public key to the authorized_keys file
echo "${public_key}" > "/home/${user_name}/.ssh/authorized_keys"
chmod 0600 "/home/${user_name}/.ssh/authorized_keys"
chown -R "${user_name}:${user_name}" "/home/${user_name}/.ssh"

# Configure sudo access for the user
echo "# User rules for ${user_name}
${user_name} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/ztpt-users
chmod 0440 /etc/sudoers.d/ztpt-users

# Restore SELinux context for the authorized_keys file
/sbin/restorecon -v "/home/${user_name}/.ssh/authorized_keys"


PYPI_URL=https://pypi.org/simple

# Setup terminal support for UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Ensure pip exists
python3 -m ensurepip

# Upgrade python build dependencies
python3 -m pip install --upgrade pip setuptools

# Install watchmaker
python3 -m pip install watchmaker boto3

# execute watchmaker
#watchmaker -e <environment> -A <admin_group> -t <computer_name> --log-dir=/var/log/watchmaker -c s3://dicelab-watchmaker/config.yaml

