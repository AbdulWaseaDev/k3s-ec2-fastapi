#!/usr/bin/env bash
# Build the app image locally and import it into k3s's containerd image
# store, so the cluster can run it without a registry.
set -euo pipefail

IMAGE_NAME="k8s-learning-app"
IMAGE_TAG="v1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAR_PATH="/tmp/${IMAGE_NAME}.tar"

echo "==> Building ${IMAGE_NAME}:${IMAGE_TAG}"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" "${SCRIPT_DIR}/app"

echo "==> Saving image to ${TAR_PATH}"
docker save "${IMAGE_NAME}:${IMAGE_TAG}" -o "${TAR_PATH}"

echo "==> Importing image into k3s containerd"
sudo k3s ctr images import "${TAR_PATH}"

echo "==> Cleaning up tarball"
rm -f "${TAR_PATH}"

echo "==> Done. Verify with:"
echo "    sudo k3s ctr images list | grep ${IMAGE_NAME}"
