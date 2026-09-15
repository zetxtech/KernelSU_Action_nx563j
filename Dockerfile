# KernelSU_Action_nx563j local build environment
#
# Usage:
#   docker build -t nx563j-kernel-build .
#   ./scripts/build-docker.sh          # mounts repo, builds, outputs to ./out
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ccache automake flex lzop bison gperf build-essential zip curl \
    zlib1g-dev libxml2-utils bzip2 libbz2-dev squashfs-tools schedtool \
    dpkg-dev lz4 make optipng libssl-dev bc unzip device-tree-compiler \
    python3 default-jdk wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# The caller mounts this repository at /scripts (see scripts/build-docker.sh).
ENTRYPOINT ["bash", "/scripts/scripts/build-kernel.sh"]