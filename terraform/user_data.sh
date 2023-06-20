#!/bin/bash

# Read public key from file
#public_key=$(cat ./pub_keys/id_rsa.pub)

# Machine-specific configurations to customize the workstation from the AMI.
useradd -m -G adm,wheel,maintuser -c "${user_name}" "${user_name}"
mkdir -m 0700 "/home/${user_name}/.ssh"
echo "${public_key}" > "/home/${user_name}/.ssh/authorized_keys"
chmod 0600 "/home/${user_name}/.ssh/authorized_keys"
chown -R "${user_name}:${user_name}" "/home/${user_name}/.ssh"

# Edit sudoers file
echo "$user_name ALL=(root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ztpt-users >/dev/null

# Mount root partition
sudo mount /dev/mapper/RootVG-rootVol /mnt

# Navigate to sudoers.d directory
sudo chroot /mnt bash -c "cd /etc/sudoers.d"

# Edit the ztpt-users file
sudo chroot /mnt visudo -f ztpt-users

# Unmount root partition
sudo umount /mnt

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
