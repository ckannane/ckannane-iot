#!/usr/bin/env bash
# Installs every tool this part needs on a fresh Debian/Ubuntu VM:
# Docker, k3d, kubectl and the argocd CLI. Idempotent: safe to re-run.
set -euo pipefail

echo ">>> Installing Docker"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  usermod -aG docker "${SUDO_USER:-vagrant}" || true
fi

echo ">>> Installing kubectl"
if ! command -v kubectl >/dev/null 2>&1; then
  KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
  curl -sLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
fi

echo ">>> Installing k3d"
if ! command -v k3d >/dev/null 2>&1; then
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

echo ">>> Installing argocd CLI"
if ! command -v argocd >/dev/null 2>&1; then
  curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  chmod +x /usr/local/bin/argocd
fi

echo ">>> All tools installed: docker, kubectl, k3d, argocd."
echo ">>> Docker group membership only applies to new sessions: log out and back"
echo ">>> in (or run 'newgrp docker') before running bootstrap.sh."
