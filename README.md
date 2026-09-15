# KernelSU Action for Nubia Z17 (nx563j)

Builds a LineageOS 22 (Android 15) kernel with [KernelSU](https://github.com/tiann/KernelSU) for the Nubia Z17 (nx563j, MSM8998), including anti-tracing procfs patches.

## Features

- Kernel source: [LineageOS android_kernel_nubia_msm8998](https://github.com/LineageOS/android_kernel_nubia_msm8998/tree/lineage-22.2), Linux 4.4 branch used by the LineageOS 22 nightlies.
- KernelSU integrated via the official `setup.sh`.
- Anti-ptrace patches (`patches/`) applied on top of the kernel:
  - `0001-proc-status-hide-tracing-stop.patch` — a traced app shows `S (sleeping)` instead of `t (tracing stop)`.
  - `0002-proc-wchan-ptrace-stop.patch` — a traced process reports `ptrace_stop` as its wchan.
  - `0003-proc-status-zero-tracer-pid.patch` — TracerPid forced to `0` while a process is being debugged.
- The built kernel is packed into the stock nx563j boot layout (header v0, permissive variant included) and re-signed with the original boot key so it boots on the device.
- Fully repeatable local build with Docker, plus the GitHub Actions pipeline.

## How the build works

The pipeline (GitHub Actions and the Docker builder share the same logic):

1. Clone kernel `lineage-22.2` from LineageOS.
2. Bootstrap KernelSU with the official script.
3. Apply the three anti-ptrace patches.
4. Build with AOSP clang (`r487747c`) + GCC 4.9 (aarch64/arm) toolchains.
5. Unpack the stock boot image from `SOURCE_BOOT_IMAGE`, replace the kernel, re-pack (normal + permissive), and sign with `boot_signer.jar`.

## Building

### GitHub Actions

Push to `master` (or trigger **Actions → Build Kernel → Run workflow**) — a boot image artifact is produced automatically. The stock boot image URL is read from `config.env` (`SOURCE_BOOT_IMAGE`); the nightly date there must be bumped to a fresh build when the old one is pulled. You can also pass a `BOOT_IMAGE_URL` input on manual runs to override it without editing the config.

### Docker (local)

```bash
docker build -t nx563j-kernel-build .
./scripts/build-docker.sh                        # uses config.env
./scripts/build-docker.sh https://mirrorbits.lineageos.org/full/nx563j/20260911/boot.img   # override stock image
```

Artifacts (`boot.img`, `boot_permissive.img`) are written to `out/`.

## Flashing

1. Back up the current boot partition (`dd if=/dev/block/bootdevice/by-name/boot of=/sdcard/boot-backup.img`).
2. Flash the artifact over Fastboot or recovery.
3. Install the KernelSU Manager APK; grant root the first time it asks.
4. To revert, flash the backup.

## Config

| Variable | Meaning |
| --- | --- |
| `KERNEL_SOURCE` | Kernel repo |
| `KERNEL_SOURCE_BRANCH` | Kernel branch (`lineage-22.2`) |
| `KERNEL_DEFCONFIG` | Defconfig (`lineageos_nx563j_defconfig`) |
| `USE_KERNELSU` | Integrate KernelSU |
| `SOURCE_BOOT_IMAGE` | Stock boot.img used for the boot layout |

## Thanks

- [LineageOS](https://lineageos.org/) — kernel and ROM.
- [KernelSU](https://github.com/tiann/KernelSU) — kernel-level root.
- [xiaoleGun](https://github.com/xiaoleGun/KernelSU_Action) — original CI script this project is based on.
- [kindle4jerry](https://github.com/kindle4jerry/boot_signer_for_nubia_nx563j) — boot signature tool.