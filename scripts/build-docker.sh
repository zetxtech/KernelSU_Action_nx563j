#!/usr/bin/env bash
#
# Host-side wrapper: builds the image and runs the kernel build in Docker.
# The repository is mounted into the container; artifacts land in ./out.
#
# Usage:
#   ./scripts/build-docker.sh [BOOT_IMG_URL]
#     BOOT_IMG_URL - optional override for the source boot.img
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${REPO_DIR}/out"
IMAGE_NAME="nx563j-kernel-build"

mkdir -p "${OUT_DIR}"

echo ">>> Building Docker image ${IMAGE_NAME}"
docker build -q -t "${IMAGE_NAME}" "${REPO_DIR}"

echo ">>> Starting kernel build inside container"
docker run --rm \
    -v "${REPO_DIR}":/scripts \
    -v "${OUT_DIR}":/out \
    -e BOOT_IMAGE_URL="${1:-}" \
    "${IMAGE_NAME}"

echo ">>> Done. Artifacts in ${OUT_DIR}"