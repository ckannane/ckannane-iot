#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${NODE_IP:?NODE_IP env var required}"
K3S_TOKEN="${K3S_TOKEN:?K3S_TOKEN env var required}"

# Find the interface that holds our static private-network IP, regardless of
# whether the distro names it eth1, enp0s8, enp0s9, etc.
IFACE=$(ip -o addr show | awk -v ip="$NODE_IP" '$0 ~ ip {print $2}' | head -n1)

# K3s recommends turning firewalld off; it blocks flannel/VXLAN between nodes.
systemctl disable --now firewalld 2>/dev/null || true

echo ">>> Installing K3s server on ${NODE_IP} (iface ${IFACE})"

curl -sfL https://get.k3s.io | K3S_TOKEN="${K3S_TOKEN}" INSTALL_K3S_EXEC="server \
  --node-ip=${NODE_IP} \
  --bind-address=${NODE_IP} \
  --advertise-address=${NODE_IP} \
  --flannel-iface=${IFACE} \
  --tls-san=${NODE_IP} \
  --write-kubeconfig-mode=644" sh -

echo ">>> Installing standalone kubectl"
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

echo ">>> Wiring up kubeconfig for vagrant user"
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
grep -qxF 'export KUBECONFIG=/home/vagrant/.kube/config' /home/vagrant/.bashrc || \
  echo 'export KUBECONFIG=/home/vagrant/.kube/config' >> /home/vagrant/.bashrc

echo ">>> K3s server ready."
