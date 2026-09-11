#!/bin/sh
# Docker Engine, on top of an image that already ran the base. The base
# drops the apt lists, so this script refreshes the index itself.
set -eu

export DEBIAN_FRONTEND=noninteractive

# Docker Engine from the upstream repo. The distro docker.io package lags
# and misses the compose and buildx plugins.
. /etc/os-release
apt-get update
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# deb822: the source format Debian 13 and Docker document.
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update
# Docker's documented install, recommends included. Dropping them loses
# the rootless extras, git, and pigz.
apt-get -y -o Dpkg::Options::=--force-confold install \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# json-file logs grow without bound on a busy clone. journald caps itself.
install -m 0755 -d /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "journald"
}
JSON
