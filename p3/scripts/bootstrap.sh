#!/usr/bin/env bash
# Creates the k3d cluster, the argocd/dev namespaces, installs Argo CD and
# points it at our GitHub repo so it deploys wil42/playground into dev.
set -euo pipefail

CLUSTER_NAME="iot-cluster"

echo ">>> Creating k3d cluster '${CLUSTER_NAME}'"
k3d cluster create "${CLUSTER_NAME}" \
  --port "8888:8888@loadbalancer" \
  --wait

echo ">>> Creating namespaces"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev    --dry-run=client -o yaml | kubectl apply -f -

echo ">>> Installing Argo CD"
# Server-side apply: some Argo CD CRDs (ApplicationSet) are too large for the
# annotation a client-side apply writes.
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s

echo ">>> Registering the Argo CD Application (deploys manifests/ from our repo into dev)"
kubectl apply -f "$(dirname "$0")/../confs/argocd-application.yaml"

echo ">>> Done. Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo
echo ">>> Access Argo CD UI with: kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo ">>> Access the app with:   curl http://localhost:8888/"
