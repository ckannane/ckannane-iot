#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${NODE_IP:?NODE_IP env var required}"
IFACE=$(ip -o addr show | awk -v ip="$NODE_IP" '$0 ~ ip {print $2}' | head -n1)

echo ">>> Installing K3s server (with built-in Traefik ingress) on ${NODE_IP} (iface ${IFACE})"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
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

# K3s watches this directory and auto-applies any manifest dropped into it,
# both on first boot and on every subsequent `vagrant provision`.
echo ">>> Deploying the three applications + ingress"
mkdir -p /var/lib/rancher/k3s/server/manifests
cp /vagrant/confs/app-one.yaml   /var/lib/rancher/k3s/server/manifests/
cp /vagrant/confs/app-two.yaml   /var/lib/rancher/k3s/server/manifests/
cp /vagrant/confs/app-three.yaml /var/lib/rancher/k3s/server/manifests/
cp /vagrant/confs/ingress.yaml   /var/lib/rancher/k3s/server/manifests/

echo ">>> K3s server ready."
