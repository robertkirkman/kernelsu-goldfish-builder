FROM debian:trixie AS build

SHELL ["/bin/bash", "-c"]

RUN <<DOCKEREOF
apt-get update
apt-get install -y rsync python3 git-core gnupg flex bison build-essential zip curl zlib1g-dev libc6-dev-i386 x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig
mkdir -p /root/bin
curl -o /root/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
chmod +x /root/bin/repo
DOCKEREOF

ENV PATH="/root/bin:$PATH"

RUN mkdir -p /root/android{,-kernel}

WORKDIR /root/android-kernel

RUN <<DOCKEREOF
repo init -b common-android16-6.12 -u https://android.googlesource.com/kernel/manifest
repo sync -c -j8
DOCKEREOF

WORKDIR /root/android

RUN <<DOCKEREOF
repo init -b android17-release -u https://android.googlesource.com/platform/manifest
repo sync -c -j8
DOCKEREOF

WORKDIR /root/android-kernel

RUN <<DOCKEREOF
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v3.2.4
git apply -v << 'PATCHEOF'
--- a/common/arch/x86/entry/common.c
+++ b/common/arch/x86/entry/common.c
@@ -44,7 +44,7 @@ static __always_inline bool do_syscall_x64(struct pt_regs *regs, int nr)
 
 	if (likely(unr < NR_syscalls)) {
 		unr = array_index_nospec(unr, NR_syscalls);
-		regs->ax = x64_sys_call(regs, unr);
+		regs->ax = sys_call_table[unr](regs);
 		return true;
 	}
 	return false;
--- a/KernelSU/kernel/core/init.c
+++ b/KernelSU/kernel/core/init.c
@@ -30,7 +30,7 @@
 #if defined(__x86_64__)
 #include <asm/cpufeature.h>
 #include <linux/version.h>
-#ifndef X86_FEATURE_INDIRECT_SAFE
+#if 0
 #error "FATAL: Your kernel is missing the indirect syscall bypass patches!"
 #endif
 #endif
@@ -85,7 +85,7 @@ module_param_named(norc, ksu_no_custom_rc, bool, 0);
 
 int __init kernelsu_init(void)
 {
-#if defined(__x86_64__)
+#if 0
     // If the kernel has the hardening patch, X86_FEATURE_INDIRECT_SAFE must be set
     if (!boot_cpu_has(X86_FEATURE_INDIRECT_SAFE)) {
         pr_alert("*************************************************************");
PATCHEOF
tools/bazel run //common:kernel_x86_64_dist -- --destdir=/root/kernel-artifacts
tools/bazel run //common-modules/virtual-device:virtual_device_x86_64_dist -- --destdir=/root/kernel-artifacts
DOCKEREOF

WORKDIR /root/android

RUN <<DOCKEREOF
git apply -v << 'PATCHEOF'
--- a/device/generic/goldfish/board/BoardConfigCommon.mk
+++ b/device/generic/goldfish/board/BoardConfigCommon.mk
@@ -45,7 +45,7 @@ BOARD_USES_SYSTEM_OTHER_ODEX :=
 BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT := true
 
 # 8G + 8M
-BOARD_SUPER_PARTITION_SIZE ?= 8598323200
+BOARD_SUPER_PARTITION_SIZE := 68786585600
 BOARD_SUPER_PARTITION_GROUPS := emulator_dynamic_partitions
 
 BOARD_EMULATOR_DYNAMIC_PARTITIONS_PARTITION_LIST := \
@@ -70,7 +70,7 @@ BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs # we never write here
 TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm
 
 # 8G
-BOARD_EMULATOR_DYNAMIC_PARTITIONS_SIZE ?= 8589934592
+BOARD_EMULATOR_DYNAMIC_PARTITIONS_SIZE := 17179869184
 
 #vendor boot
 BOARD_INCLUDE_DTB_IN_BOOTIMG := false
PATCHEOF
for module_type in gki goldfish; do
    module_dest_dir="prebuilts/qemu-kernel/x86_64/6.12/${module_type}_modules"
    for module in $(ls $module_dest_dir); do
        if [ -f /root/kernel-artifacts/$module ]; then
            cp /root/kernel-artifacts/$module $module_dest_dir/$module
        fi
    done
done
cp /root/kernel-artifacts/bzImage prebuilts/qemu-kernel/x86_64/6.12/kernel-6.12
source build/envsetup.sh
lunch sdk_phone64_x86_64-cp2a-userdebug
m
DOCKEREOF

RUN mkdir -p /root/goldfish

RUN mv /root/android/out/target/product/emu64x /root/goldfish/

RUN mv /root/android/prebuilts/android-emulator/linux-x86_64 /root/goldfish/

# due to https://github.com/moby/buildkit/issues/2950, it is necessary to compress
# the entire build into a single archive before exporting from inside Docker to outside Docker
RUN tar czf /root/goldfish.tar.gz -C /root/goldfish .

FROM scratch
COPY --from=build /root/goldfish.tar.gz /
