#!/usr/bin/env bash
# Usage: ./set_version.sh v1|v2
# Updates the image tag in the local GitLab repo clone made by setup.sh and
# pushes it, so Argo CD picks up and syncs the change automatically.
set -euo pipefail

VERSION="${1:?usage: set_version.sh v1|v2}"
WORKDIR="${WORKDIR:-$HOME/ckannane-iot-gitlab}"
FILE="${WORKDIR}/deployment.yaml"

sed -i -E "s#(image: wil42/playground:)v[0-9]+#\1${VERSION}#" "$FILE"
grep image "$FILE"

git -C "${WORKDIR}" add deployment.yaml
git -C "${WORKDIR}" commit -m "switch wil-playground to ${VERSION}"
git -C "${WORKDIR}" push
