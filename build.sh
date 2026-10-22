#!/bin/bash
set -e

export RDIR="$(pwd)"
export ARCH=arm64
export KBUILD_BUILD_USER="@rajput_harshil"
export KBUILD_BUILD_HOST="Builder"

# Toolchains
if [ -d "${RDIR}/toolchain/clang-r416183b/bin" ]; then
    export CLANG_TOOL_PATH="${RDIR}/toolchain/clang-r416183b/bin"
    export PATH="${CLANG_TOOL_PATH}:${PATH}"
    export BUILD_CC="${CLANG_TOOL_PATH}/clang"
    export BUILD_LD="${CLANG_TOOL_PATH}/ld.lld"
elif [ -d "${RDIR}/toolchain/clang/host/linux-x86/clang-r383902/bin" ]; then
    export CLANG_TOOL_PATH="${RDIR}/toolchain/clang/host/linux-x86/clang-r383902/bin"
    export PATH="${CLANG_TOOL_PATH}:${PATH}"
    export BUILD_CC="${CLANG_TOOL_PATH}/clang"
    export BUILD_LD="${CLANG_TOOL_PATH}/ld.lld"
else
    export BUILD_CC="clang"
    export BUILD_LD="ld.lld"
fi

if [ -d "${RDIR}/toolchain/aarch64-linux-android-4.9-llvm/bin" ]; then
    export GCC_TOOL_PATH="${RDIR}/toolchain/aarch64-linux-android-4.9-llvm/bin"
    export PATH="${GCC_TOOL_PATH}:${PATH}"
    export BUILD_CROSS_COMPILE="${GCC_TOOL_PATH}/aarch64-linux-android-"
elif [ -d "${RDIR}/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin" ]; then
    export GCC_TOOL_PATH="${RDIR}/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin"
    export PATH="${GCC_TOOL_PATH}:${PATH}"
    export BUILD_CROSS_COMPILE="${GCC_TOOL_PATH}/aarch64-linux-android-"
else
    export BUILD_CROSS_COMPILE="aarch64-linux-gnu-"
fi

# Ensure dtc is executable
if [ -f "${RDIR}/tools/dtc" ]; then
    chmod +x "${RDIR}/tools/dtc"
    export KERNEL_MAKE_ENV="DTC_EXT=${RDIR}/tools/dtc CONFIG_BUILD_ARM64_DT_OVERLAY=y"
else
    export KERNEL_MAKE_ENV="CONFIG_BUILD_ARM64_DT_OVERLAY=y"
fi

# Output & build directory
mkdir -p "${RDIR}/out"
mkdir -p "${RDIR}/build/modules"

# Kernel version tag
if [ -z "$BUILD_KERNEL_VERSION" ]; then
    export BUILD_KERNEL_VERSION="v1.0"
fi

# Compile Kernel
build_kernel() {
    echo "======================================================"
    echo "  Building SM-A235F Kernel (Snapdragon 680 / SM6225) "
    echo "======================================================"
    
    local DEFCONFIG="vendor/a23_eur_open_mizkernel_defconfig"
    if [ ! -f "${RDIR}/arch/arm64/configs/${DEFCONFIG}" ]; then
        DEFCONFIG="vendor/a23_eur_open_defconfig"
    fi

    echo "[+] Using defconfig: ${DEFCONFIG}"
    make -C "${RDIR}" O="${RDIR}/out" \
        ${KERNEL_MAKE_ENV} \
        ARCH=arm64 \
        CROSS_COMPILE="${BUILD_CROSS_COMPILE}" \
        REAL_CC="${BUILD_CC}" \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CONFIG_SECTION_MISMATCH_WARN_ONLY=y \
        "${DEFCONFIG}"

    echo "[+] Configuring KernelSU & Security Features..."
    "${RDIR}/scripts/config" --file "${RDIR}/out/.config" -e KSU || true
    "${RDIR}/scripts/config" --file "${RDIR}/out/.config" -e OVERLAY_FS || true
    "${RDIR}/scripts/config" --file "${RDIR}/out/.config" -e KPROBES || true
    "${RDIR}/scripts/config" --file "${RDIR}/out/.config" -e HAVE_KPROBES || true
    "${RDIR}/scripts/config" --file "${RDIR}/out/.config" -e KPROBE_EVENTS || true
    "${RDIR}/scripts/config" --file "${RDIR}/out/.config" -e KRETPROBES || true
    "${RDIR}/scripts/config" --file "${RDIR}/out/.config" -e HAVE_KRETPROBES || true
    "${RDIR}/scripts/config" --file "${RDIR}/out/.config" -d UH || true
    "${RDIR}/scripts/config" --file "${RDIR}/out/.config" -d RKP || true
    "${RDIR}/scripts/config" --file "${RDIR}/out/.config" -d KDP || true
    "${RDIR}/scripts/config" --file "${RDIR}/out/.config" -d KDP_CRED || true
    "${RDIR}/scripts/config" --file "${RDIR}/out/.config" -d KDP_NS || true

    JOBS=$(nproc 2>/dev/null || echo 4)
    echo "[+] Compiling Kernel Image with ${JOBS} parallel jobs..."
    make -C "${RDIR}" O="${RDIR}/out" \
        ${KERNEL_MAKE_ENV} \
        ARCH=arm64 \
        CROSS_COMPILE="${BUILD_CROSS_COMPILE}" \
        REAL_CC="${BUILD_CC}" \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CONFIG_SECTION_MISMATCH_WARN_ONLY=y \
        -j"${JOBS}" Image
    
    mkdir -p "${RDIR}/arch/arm64/boot"
    cp "${RDIR}/out/arch/arm64/boot/Image" "${RDIR}/arch/arm64/boot/Image"
    cp "${RDIR}/out/arch/arm64/boot/Image" "${RDIR}/build/Image"
    echo "[+] Kernel Image built successfully: ${RDIR}/build/Image"
}

# Repack boot.img
build_boot() {
    if [ -d "${RDIR}/AIK-Linux" ] && [ -f "${RDIR}/AIK-Linux/repackimg.sh" ]; then
        echo "======================================================"
        echo "  Repacking boot.img via AIK                          "
        echo "======================================================"
        rm -f "${RDIR}/AIK-Linux/split_img/boot.img-kernel" "${RDIR}/AIK-Linux/boot.img" "${RDIR}/AIK-Linux/image-new.img"
        cp "${RDIR}/out/arch/arm64/boot/Image" "${RDIR}/AIK-Linux/split_img/boot.img-kernel"
        
        cd "${RDIR}/AIK-Linux"
        chmod +x repackimg.sh bin/* 2>/dev/null || true
        ./repackimg.sh --nosudo || true
        
        if [ -f "image-new.img" ]; then
            mv image-new.img "${RDIR}/build/boot.img"
            echo -n "SEANDROIDENFORCE" >> "${RDIR}/build/boot.img"
            echo "[+] Boot image created successfully with Samsung SEANDROIDENFORCE signature: ${RDIR}/build/boot.img"
        fi
        cd "${RDIR}"
    fi
}

# Build flashable Odin tar and AnyKernel3 zip
build_packages() {
    echo "======================================================"
    echo "  Packaging Flashable Releases                        "
    echo "======================================================"
    
    cd "${RDIR}/build"
    if [ -f "boot.img" ]; then
        tar -cvf "Kernel-SM-A235F-${BUILD_KERNEL_VERSION}.tar" boot.img
        echo "[+] Odin Flashable TAR created: build/Kernel-SM-A235F-${BUILD_KERNEL_VERSION}.tar"

        if command -v lz4 >/dev/null 2>&1; then
            lz4 -B6 --content-size -f boot.img boot.img.lz4
            tar -cvf "Kernel-SM-A235F-${BUILD_KERNEL_VERSION}-Odin.tar" boot.img.lz4
            echo "[+] Samsung LZ4 Odin Flashable TAR created: build/Kernel-SM-A235F-${BUILD_KERNEL_VERSION}-Odin.tar"
        fi
    fi

    # AnyKernel3 recovery zip
    if [ -d "${RDIR}/AnyKernel3" ] && [ -f "${RDIR}/build/Image" ]; then
        echo "[+] Building AnyKernel3 Recovery Flashable ZIP..."
        rm -rf "${RDIR}/AnyKernel3_pkg"
        cp -r "${RDIR}/AnyKernel3" "${RDIR}/AnyKernel3_pkg"
        cp "${RDIR}/build/Image" "${RDIR}/AnyKernel3_pkg/Image"
        cd "${RDIR}/AnyKernel3_pkg"
        zip -r9 "${RDIR}/build/AnyKernel3-SM-A235F-${BUILD_KERNEL_VERSION}.zip" * -x "*.git*"
        rm -rf "${RDIR}/AnyKernel3_pkg"
        echo "[+] AnyKernel3 ZIP created: build/AnyKernel3-SM-A235F-${BUILD_KERNEL_VERSION}.zip"
    fi
    cd "${RDIR}"

    # Copy on-device flasher
    if [ -f "${RDIR}/flash_kernel.sh" ]; then
        cp "${RDIR}/flash_kernel.sh" "${RDIR}/build/"
    fi
}

# Execute sequence
build_kernel
build_boot
build_packages

# Build external memkernel modules
if [ -f "${RDIR}/build_external_module.sh" ]; then
    echo "======================================================"
    echo "  Building MemKernel / RTDev Modules                  "
    echo "======================================================"
    bash "${RDIR}/build_external_module.sh"
fi

echo -e "\n[✔] All SM-A235F Builds & Driver Packaging Completed Successfully!\n"
