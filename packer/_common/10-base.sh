#!/bin/sh
# Base layer of the base image: the Debian baseline every other image
# inherits from it. Standalone and re-runnable.
set -eu

export DEBIAN_FRONTEND=noninteractive

# A build has no terminal to answer the dpkg prompt on a config conflict.
apt-get update
apt-get -y -o Dpkg::Options::=--force-confold upgrade

# Neither ships in the standard template: curl fetches the keys of the
# repositories the images above add, ca-certificates validates those
# fetches.
apt-get -y --no-install-recommends install curl ca-certificates

# LXC runs no networkd. The wait unit only delays a clone boot.
systemctl disable --now systemd-networkd-wait-online.service >/dev/null 2>&1 || true
