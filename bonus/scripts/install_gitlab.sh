#!/usr/bin/env bash
# Installs a local GitLab instance into the k3d cluster from Part 3, in its
# own 'gitlab' namespace, via the official Helm chart.
set -euo pipefail

DOMAIN="${1:-gitlab.local}"

echo ">>> Installing Helm (if missing)"
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo ">>> Creating gitlab namespace"
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -

echo ">>> Adding the GitLab Helm repo"
helm repo add gitlab https://charts.gitlab.io/
helm repo update

echo ">>> Installing GitLab (this can take 10-20 minutes on first install)"
helm upgrade --install gitlab gitlab/gitlab \
  -n gitlab \
  -f "$(dirname "$0")/../confs/values.yaml" \
  --set global.hosts.domain="${DOMAIN}" \
  --timeout 600s

echo ">>> GitLab is deploying. Watch it with:"
echo "    kubectl -n gitlab get pods -w"
echo ">>> Once ready, fetch the initial root password with:"
echo "    kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 -d"
