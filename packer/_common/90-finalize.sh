#!/bin/sh
# Last script of every image, for two reasons.
#
# 1. Identity. The build boots the container, so systemd regenerates
#    /etc/machine-id and sshd its host keys. Clearing them in an earlier
#    image doesn't hold: the next boot recreates them. In a chain, only
#    the last build can leave a clean identity.
# 2. apt. The lists must go after the last install, or every image hauls
#    them around.
set -eu

# sshd doesn't generate missing host keys itself, so a oneshot unit does
# it before ssh starts.
cat > /etc/systemd/system/ssh-host-keys.service <<'UNIT'
[Unit]
Description=Generate SSH host keys when missing
ConditionPathExists=!/etc/ssh/ssh_host_ed25519_key
Before=ssh.service

[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A

[Install]
WantedBy=multi-user.target
UNIT
systemctl enable ssh-host-keys.service

# A shared root password or a shared host key in the template would leak
# into every clone.
passwd -l root
rm -f /etc/ssh/ssh_host_*
truncate -s 0 /etc/machine-id

# Standard image hygiene: a stale list pins clones to old package
# versions, and an apt task on a clone updates the cache itself.
apt-get -y autoremove
apt-get -y autoclean
apt-get -y clean
rm -rf /var/lib/apt/lists/*
