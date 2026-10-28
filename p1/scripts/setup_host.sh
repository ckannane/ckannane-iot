#!/usr/bin/env bash
# Prepares the Debian/Ubuntu host VM that runs Parts 1 and 2: installs
# VirtualBox and Vagrant from their vendors' apt repos. Idempotent.
# Run as root, or with sudo.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash "$0" "$@"
fi

. /etc/os-release
CODENAME="${VERSION_CODENAME}"

echo ">>> Checking nested virtualization"
if ! grep -Eq '(vmx|svm)' /proc/cpuinfo; then
  echo "!!! VT-x/AMD-V is not visible in this VM: enable nested virtualization" >&2
  echo "!!! on the outer hypervisor first, or vagrant up will fail." >&2
  exit 1
fi

echo ">>> Installing base packages"
apt-get update
apt-get install -y git curl wget gpg build-essential "linux-headers-$(uname -r)"

echo ">>> Adding the VirtualBox apt repo (${CODENAME})"
wget -qO- https://www.virtualbox.org/download/oracle_vbox_2016.asc \
  | gpg --dearmor --yes -o /usr/share/keyrings/oracle-vbox.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-vbox.gpg] https://download.virtualbox.org/virtualbox/debian ${CODENAME} contrib" \
  > /etc/apt/sources.list.d/virtualbox.list

echo ">>> Adding the HashiCorp apt repo (${CODENAME})"
wget -qO- https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor --yes -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com ${CODENAME} main" \
  > /etc/apt/sources.list.d/hashicorp.list

echo ">>> Installing VirtualBox and Vagrant"
apt-get update
apt-get install -y virtualbox-7.2 vagrant

if [ -n "${SUDO_USER:-}" ]; then
  usermod -aG vboxusers "${SUDO_USER}"
  echo ">>> Added ${SUDO_USER} to vboxusers: log out and back in before vagrant up."
fi

echo ">>> Done:"
VBoxManage --version
vagrant --version
