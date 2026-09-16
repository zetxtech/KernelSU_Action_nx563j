#!/usr/bin/env bash
# Replicate the CI "Build kernel" step locally with the same commands.
set -euo pipefail

REPO=${REPO:-/scripts}
WS=${WS:-/workspace}
# Pre-cloned kernel source is mounted at /kernel-src
KERNEL_SRC=${KERNEL_SRC:-/kernel-src}

cd "${WS}"

echo "==> Downloading toolchains"
if [ ! -x clang-aosp/bin/clang ]; then
    mkdir -p clang-aosp gcc-aosp gcc32-aosp
    wget -q "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android15-qpr2-release/clang-r536225.tar.gz" -O clang.tar.gz
    tar -C clang-aosp -zxf clang.tar.gz
    wget -q "https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/refs/tags/android-12.1.0_r27.tar.gz" -O gcc.tar.gz
    tar -C gcc-aosp -zxf gcc.tar.gz
    wget -q "https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/refs/tags/android-12.1.0_r27.tar.gz" -O gcc32.tar.gz
    tar -C gcc32-aosp -zxf gcc32.tar.gz
fi

# Toolchains (downloaded inside the container before this script runs)
CLANG_AOSP=${WS}/clang-aosp
GCC_AOSP=${WS}/gcc-aosp
GCC32_AOSP=${WS}/gcc32-aosp

echo "==> Copying kernel source"
rm -rf android-kernel
mkdir -p android-kernel
cp -a "${KERNEL_SRC}/." android-kernel/

echo "==> Setup KernelSU (v0.9.5, last release supporting 4.4 kernels)"
cd android-kernel
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/v0.9.5/kernel/setup.sh" | bash -s v0.9.5
echo "==> Apply anti-ptrace patches"
for p in "${REPO}"/patches/*.patch; do
    echo "Applying $(basename "${p}")"
    git apply "${p}"
done

echo "==> Build kernel"
export PATH="${CLANG_AOSP}/bin:${PATH}"
make -j"$(nproc --all)" O=out ARCH=arm64 \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE="${GCC_AOSP}/bin/aarch64-linux-android-" \
    CROSS_COMPILE_ARM32="${GCC32_AOSP}/bin/arm-linux-androideabi-" \
    CROSS_COMPILE_COMPAT="${GCC32_AOSP}/bin/arm-linux-androideabi-" \
    CC=clang LD=ld.lld LLVM=1 LLVM_IAS=1 lineageos_nx563j_defconfig
make -j"$(nproc --all)" O=out ARCH=arm64 \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE="${GCC_AOSP}/bin/aarch64-linux-android-" \
    CROSS_COMPILE_ARM32="${GCC32_AOSP}/bin/arm-linux-androideabi-" \
    CROSS_COMPILE_COMPAT="${GCC32_AOSP}/bin/arm-linux-androideabi-" \
    CC=clang LD=ld.lld LLVM=1 LLVM_IAS=1
echo "==> Build finished"