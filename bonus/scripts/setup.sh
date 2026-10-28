#!/usr/bin/env bash
# Adds a local GitLab (namespace 'gitlab') to the Part 3 k3d lab, pushes the
# app manifests to a repo on it, and points Argo CD at that repo instead of
# GitHub. Run after p3/scripts/install.sh; creates the Part 3 cluster if needed.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CLUSTER_NAME="iot-cluster"
GITLAB_HOST="gitlab.k3d.local"
REPO_NAME="ckannane-iot"
WORKDIR="${WORKDIR:-$HOME/${REPO_NAME}-gitlab}"

echo ">>> Installing Helm (if missing)"
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

if ! k3d cluster list "${CLUSTER_NAME}" >/dev/null 2>&1; then
  echo ">>> Part 3 cluster not found, bootstrapping it first"
  bash "${HERE}/../../p3/scripts/bootstrap.sh"
fi

echo ">>> Exposing Traefik (port 80) on the k3d load balancer"
if ! docker port "k3d-${CLUSTER_NAME}-serverlb" 80 >/dev/null 2>&1; then
  k3d cluster edit "${CLUSTER_NAME}" --port-add "80:80@loadbalancer"
fi

echo ">>> Resolving ${GITLAB_HOST} to this machine"
grep -q " ${GITLAB_HOST}$" /etc/hosts || \
  echo "127.0.0.1 ${GITLAB_HOST}" | sudo tee -a /etc/hosts >/dev/null

echo ">>> Creating gitlab namespace"
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -

echo ">>> Installing GitLab from the official Helm chart (10-20 minutes on first install)"
helm repo add gitlab https://charts.gitlab.io/ --force-update
helm repo update gitlab
helm upgrade --install gitlab gitlab/gitlab \
  -n gitlab \
  -f "${HERE}/../confs/values.yaml" \
  --timeout 600s

kubectl -n gitlab rollout status deployment/gitlab-webservice-default --timeout=1800s
until curl -sf -o /dev/null "http://${GITLAB_HOST}/users/sign_in"; do
  echo "    waiting for http://${GITLAB_HOST} ..."
  sleep 10
done

ROOT_PASS=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password \
  -o jsonpath='{.data.password}' | base64 -d)

echo ">>> Pushing the app manifests to http://${GITLAB_HOST}/root/${REPO_NAME}"
# GitLab creates the project on first push into the user's namespace.
if [ ! -d "${WORKDIR}/.git" ]; then
  mkdir -p "${WORKDIR}"
  cp "${HERE}/../confs/app/"*.yaml "${WORKDIR}/"
  git -C "${WORKDIR}" init -q -b main
  git -C "${WORKDIR}" config user.name  "ckannane"
  git -C "${WORKDIR}" config user.email "ckannane@${GITLAB_HOST}"
  git -C "${WORKDIR}" add .
  git -C "${WORKDIR}" commit -q -m "wil-playground v1"
  git -C "${WORKDIR}" remote add origin \
    "http://root:${ROOT_PASS}@${GITLAB_HOST}/root/${REPO_NAME}.git"
fi
git -C "${WORKDIR}" push -u origin main

echo ">>> Giving Argo CD read access to the GitLab repo"
kubectl -n argocd create secret generic gitlab-repo \
  --from-literal=type=git \
  --from-literal=url="http://gitlab-webservice-default.gitlab.svc:8181/root/${REPO_NAME}.git" \
  --from-literal=username=root \
  --from-literal=password="${ROOT_PASS}" \
  --dry-run=client -o yaml \
  | kubectl label --local -f - argocd.argoproj.io/secret-type=repository -o yaml \
  | kubectl apply -f -

echo ">>> Switching the Argo CD Application from GitHub to GitLab"
kubectl apply -f "${HERE}/../confs/argocd-application.yaml"

echo
echo ">>> Done."
echo "    GitLab UI:   http://${GITLAB_HOST}  (user: root, password: ${ROOT_PASS})"
echo "    Repo clone:  ${WORKDIR}"
echo "    App:         curl http://localhost:8888/"
echo "    Switch tag:  ${HERE}/set_version.sh v2"
