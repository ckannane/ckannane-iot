#!/usr/bin/env bash
# Usage: ./set_version.sh v1|v2
# Updates the image tag in confs/app/deployment.yaml and pushes to GitHub so
# Argo CD picks up and syncs the change automatically.
set -euo pipefail

VERSION="${1:?usage: set_version.sh v1|v2}"
FILE="$(dirname "$0")/../confs/app/deployment.yaml"

sed -i -E "s#(image: wil42/playground:)v[0-9]+#\1${VERSION}#" "$FILE"
grep image "$FILE"

git -C "$(dirname "$0")/../.." add p3/confs/app/deployment.yaml
git -C "$(dirname "$0")/../.." commit -m "p3: switch wil-playground to ${VERSION}"
git -C "$(dirname "$0")/../.." push
