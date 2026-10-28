#!/usr/bin/env bash
set -euo pipefail

NODE_IP="${NODE_IP:?NODE_IP env var required}"
SERVER_IP="${SERVER_IP:?SERVER_IP env var required}"
K3S_TOKEN="${K3S_TOKEN:?K3S_TOKEN env var required}"

IFACE=$(ip -o addr show | awk -v ip="$NODE_IP" '$0 ~ ip {print $2}' | head -n1)

systemctl disable --now firewalld 2>/dev/null || true

echo ">>> Installing K3s agent on ${NODE_IP} (iface ${IFACE}), joining ${SERVER_IP}"

curl -sfL https://get.k3s.io | \
  K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="${K3S_TOKEN}" \
  INSTALL_K3S_EXEC="agent --node-ip=${NODE_IP} --flannel-iface=${IFACE}" sh -

echo ">>> Installing standalone kubectl"
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

echo ">>> K3s agent ready."
