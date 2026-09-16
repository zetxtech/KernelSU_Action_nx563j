#!/usr/bin/env bash
#
# In-container kernel build for nx563j. Runs from /workspace; the repo is
# mounted at /scripts, artifacts are written to /out.
set -euo pipefail

REPO=/scripts
WS=/workspace
OUT=/out

cd "${WS}"

# --- Load configuration ---------------------------------------------
load_cfg() {
    local key="$1"
    grep "^${key}=" "${REPO}/config.env" | head -n 1 | cut -d= -f2
}
KERNEL_SOURCE="$(load_cfg KERNEL_SOURCE)"
KERNEL_SOURCE_BRANCH="$(load_cfg KERNEL_SOURCE_BRANCH)"
KERNEL_DEFCONFIG="$(load_cfg KERNEL_DEFCONFIG)"
TARGET_ARCH="$(load_cfg TARGET_ARCH)"
KERNEL_FILE="$(load_cfg KERNEL_FILE)"
CLANG_VERSION="$(load_cfg CLANG_VERSION)"
# EXTRA_BUILD_COMMAND uses a colon separator in config.env (like the CI parser)
BUILD_EXTRA_COMMAND="$(grep '^EXTRA_BUILD_COMMAND' "${REPO}/config.env" | head -n 1 | cut -d: -f2-)"
USE_KERNELSU="$(load_cfg USE_KERNELSU)"
KERNELSU_VERSION="$(load_cfg KERNELSU_VERSION)"
MAKE_BOOT_IMAGE="$(load_cfg MAKE_BOOT_IMAGE)"
BOOT_SIGNATURE="$(load_cfg BOOT_SIGNATURE)"
SOURCE_BOOT_IMAGE="${BOOT_IMAGE_URL:-$(load_cfg SOURCE_BOOT_IMAGE)}"

echo "==> Config: source=${KERNEL_SOURCE} branch=${KERNEL_SOURCE_BRANCH} defconfig=${KERNEL_DEFCONFIG}"

# --- Toolchains ------------------------------------------------------
download_verified() {
    local url="$1" out="$2"
    for i in 1 2 3 4 5; do
        wget -q -c --tries=3 --timeout=60 -O "${out}" "${url}" || true
        if gzip -t "${out}" 2>/dev/null; then
            echo "Download OK (attempt ${i}): ${out}"
            return 0
        fi
        echo "Truncated download (attempt ${i}), retrying..."
        rm -f "${out}"
        sleep 5
    done
    return 1
}
mkdir -p clang-aosp gcc-aosp gcc32-aosp
echo "==> Downloading clang-${CLANG_VERSION}"
download_verified "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android15-qpr2-release/clang-${CLANG_VERSION}.tar.gz" clang.tar.gz
tar -C clang-aosp -zxf clang.tar.gz
echo "==> Downloading GCC toolchains"
wget -q "https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/refs/tags/android-12.1.0_r27.tar.gz" -O gcc.tar.gz
tar -C gcc-aosp -zxf gcc.tar.gz
wget -q "https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/refs/tags/android-12.1.0_r27.tar.gz" -O gcc32.tar.gz
tar -C gcc32-aosp -zxf gcc32.tar.gz

# --- Kernel source ---------------------------------------------------
echo "==> Cloning kernel"
git clone --depth=1 -b "${KERNEL_SOURCE_BRANCH}" "${KERNEL_SOURCE}" android-kernel

if [ "${MAKE_BOOT_IMAGE}" = "true" ]; then
    echo "==> Downloading mkbootimg tools"
    git clone --depth=1 -b main-kernel-build-2023 https://android.googlesource.com/platform/system/tools/mkbootimg tools
    echo "==> Downloading source boot image"
    wget -q -L -O boot-source.img "${SOURCE_BOOT_IMAGE}"
fi
if [ "${BOOT_SIGNATURE}" = "true" ]; then
    echo "==> Downloading boot signer"
    git clone --depth=1 -b main https://github.com/kindle4jerry/boot_signer_for_nubia_nx563j bootsigner
fi

# --- KernelSU --------------------------------------------------------
if [ "${USE_KERNELSU}" = "true" ]; then
    echo "==> Setting up KernelSU ${KERNELSU_VERSION}"
    cd android-kernel
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/${KERNELSU_VERSION}/kernel/setup.sh" | bash -s "${KERNELSU_VERSION}"
    cd "${WS}"
fi

# --- Patches ---------------------------------------------------------
echo "==> Applying anti-ptrace patches"
cd android-kernel
for p in "${REPO}"/patches/*.patch; do
    echo "Applying $(basename "${p}")"
    git apply "${p}"
done
cd "${WS}"

# --- Build -----------------------------------------------------------
echo "==> Building kernel"
export PATH="${WS}/clang-aosp/bin:${PATH}"
cd android-kernel
make -j"$(nproc --all)" O=out ARCH="${TARGET_ARCH}" \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE="${WS}/gcc-aosp/bin/aarch64-linux-android-" \
    CROSS_COMPILE_ARM32="${WS}/gcc32-aosp/bin/arm-linux-androideabi-" \
    CROSS_COMPILE_COMPAT="${WS}/gcc32-aosp/bin/arm-linux-androideabi-" \
    CC=clang ${BUILD_EXTRA_COMMAND} "${KERNEL_DEFCONFIG}"
make -j"$(nproc --all)" O=out ARCH="${TARGET_ARCH}" \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE="${WS}/gcc-aosp/bin/aarch64-linux-android-" \
    CROSS_COMPILE_ARM32="${WS}/gcc32-aosp/bin/arm-linux-androideabi-" \
    CROSS_COMPILE_COMPAT="${WS}/gcc32-aosp/bin/arm-linux-androideabi-" \
    CC=clang ${BUILD_EXTRA_COMMAND}
cd "${WS}"

# --- Boot image ------------------------------------------------------
if [ "${MAKE_BOOT_IMAGE}" = "true" ]; then
    echo "==> Packing boot image"
    tools/unpack_bootimg.py --boot_img boot-source.img
    cp "android-kernel/out/arch/${TARGET_ARCH}/boot/${KERNEL_FILE}" out/kernel
    tools/mkbootimg.py "$(tools/unpack_bootimg.py --boot_img=boot-source.img --format mkbootimg)" -o boot_unsign.img

    CMDBUF='androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x37 ehci-hcd.park=3 lpm_levels.sleep_disabled=1 sched_enable_hmp=1 sched_enable_power_aware=1 service_locator.enable=1 swiotlb=2048 androidboot.usbconfigfs=true androidboot.usbcontroller=a800000.dwc3 androidboot.selinux=permissive loop.max_part=7'
    tools/mkbootimg.py --header_version 0 --os_version 15.0.0 --os_patch_level 2026-09 \
        --kernel out/kernel --ramdisk out/ramdisk --pagesize 0x00001000 \
        --base 0x00000000 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 \
        --second_offset 0x00000000 --tags_offset 0x00000100 --board '' \
        --cmdline "${CMDBUF}" -o bootp_unsign.img

    if [ "${BOOT_SIGNATURE}" = "true" ]; then
        echo "==> Signing boot images"
        java -jar bootsigner/boot_signer.jar /boot boot_unsign.img bootsigner/verity.pk8 bootsigner/verity.x509.pem "${OUT}/boot.img"
        java -jar bootsigner/boot_signer.jar /boot bootp_unsign.img bootsigner/verity.pk8 bootsigner/verity.x509.pem "${OUT}/boot_permissive.img"
    else
        cp boot_unsign.img "${OUT}/boot.img"
        cp bootp_unsign.img "${OUT}/boot_permissive.img"
    fi
fi

ls -lh "${OUT}"
echo "==> Build finished."