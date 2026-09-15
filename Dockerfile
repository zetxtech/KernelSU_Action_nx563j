# KernelSU_Action_nx563j local build environment
#
# Usage:
#   docker build -t nx563j-kernel-build .
#   ./scripts/build-docker.sh          # mounts repo, builds, outputs to ./out
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ccache automake flex lzop bison gperf build-essential zip curl \
    zlib1g-dev g++-multilib libxml2-utils bzip2 libbz2-dev squashfs-tools \
    pngcrush schedtool dpkg-dev liblz4-tool make optipng maven libssl-dev \
    pwgen libswitch-perl policycoreutils minicom libxml-sax-base-perl \
    libxml-simple-perl bc libc6-dev-i386 libx11-dev lib32z-dev \
    libgl1-mesa-dev xsltproc unzip device-tree-compiler python3 default-jdk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# The caller mounts this repository at /scripts (see scripts/build-docker.sh).
ENTRYPOINT ["bash", "/scripts/scripts/build-kernel.sh"]