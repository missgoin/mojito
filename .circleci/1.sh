#!/usr/bin/bash
# Written by: cyberknight777
# YAKB v1.0
# Copyright (c) 2022-2023 Cyber Knight <cyberknight755@gmail.com>
#
#			GNU GENERAL PUBLIC LICENSE
#			 Version 3, 29 June 2007
#
# Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
# Everyone is permitted to copy and distribute verbatim copies
# of this license document, but changing it is not allowed.

# Some Placeholders: [!] [*] [✓] [✗]

# Default defconfig to use for builds.
export CONFIG=neternels_defconfig

# Default directory where kernel is located in.
KDIR=$(pwd)
export KDIR

# Default linker to use for builds.
export LINKER="ld.lld"

# Device name.
export DEVICE="Redmi Note 10"

# Date of build.
DATE=$(date +"%Y-%m-%d")
export DATE

# Device codename.
export CODENAME="sunny"

# Builder name.
export BUILDER="unknown"

FINAL_ZIP_ALIAS=Karenulmoji-${TANGGAL}.zip

# Kernel repository URL.
#export REPO_URL="https://github.com/neternels/android_kernel_xiaomi_sunny"

# Commit hash of HEAD.
COMMIT_HASH=$(git rev-parse --short HEAD)
export COMMIT_HASH


# Number of jobs to run.
PROCS=$(nproc --all)
export PROCS

# Compiler to use for builds.
export COMPILER=gcc

# Module building support. Set 1 to enable. | Set 0 to disable.
export MODULE=1


if [[ "${COMPILER}" == gcc ]]; then
    if [ ! -d "${KDIR}/gcc64" ]; then
        curl -sL https://github.com/cyberknight777/gcc-arm64/archive/refs/heads/master.tar.gz | tar -xzf -
        mv "${KDIR}"/gcc-arm64-master "${KDIR}"/gcc64
    fi

    if [ ! -d "${KDIR}/gcc32" ]; then
	curl -sL https://github.com/cyberknight777/gcc-arm/archive/refs/heads/master.tar.gz | tar -xzf -
        mv "${KDIR}"/gcc-arm-master "${KDIR}"/gcc32
    fi

    KBUILD_COMPILER_STRING=$("${KDIR}"/gcc64/bin/aarch64-elf-gcc --version | head -n 1)
    export KBUILD_COMPILER_STRING
    export PATH="${KDIR}"/gcc32/bin:"${KDIR}"/gcc64/bin:/usr/bin/:${PATH}
    MAKE+=(
        ARCH=arm64
        O=out
        CROSS_COMPILE=aarch64-elf-
        CROSS_COMPILE_ARM32=arm-eabi-
        LD="${KDIR}"/gcc64/bin/aarch64-elf-"${LINKER}"
        AR=llvm-ar
        NM=llvm-nm
        OBJDUMP=llvm-objdump
        OBJCOPY=llvm-objcopy
        OBJSIZE=llvm-objsize
        STRIP=llvm-strip
        HOSTAR=llvm-ar
        HOSTCC=gcc
        HOSTCXX=aarch64-elf-g++
        CC=aarch64-elf-gcc
    )

elif [[ "${COMPILER}" == clang ]]; then
    if [ ! -d "${KDIR}/proton-clang" ]; then
        wget https://github.com/kdrag0n/proton-clang/archive/refs/heads/master.zip
        unzip "${KDIR}"/master.zip
        mv "${KDIR}"/proton-clang-master "${KDIR}"/proton-clang
    fi

    KBUILD_COMPILER_STRING=$("${KDIR}"/proton-clang/bin/clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')
    export KBUILD_COMPILER_STRING
    export PATH=$KDIR/proton-clang/bin/:/usr/bin/:${PATH}
    MAKE+=(
        ARCH=arm64
        O=out
        CROSS_COMPILE=aarch64-linux-gnu-
        CROSS_COMPILE_ARM32=arm-linux-gnueabi-
        LD="${LINKER}"
        AR=llvm-ar
        AS=llvm-as
        NM=llvm-nm
        OBJDUMP=llvm-objdump
        STRIP=llvm-strip
        CC=clang
    )
fi


if [ ! -d "${KDIR}/anykernel3-sunny/" ]; then
    git clone --depth=1 https://github.com/neternels/anykernel3 -b sunny anykernel3-sunny
fi

    export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
    export KBUILD_BUILD_HOST=$DRONE_SYSTEM_HOST
    export KBUILD_BUILD_USER=$BUILDER
    export VERSION=$version
    kver=$KBUILD_BUILD_VERSION
    zipn=NetErnels-sunny-${VERSION}


# A function to exit on SIGINT.
exit_on_signal_SIGINT() {
    echo -e "\n\n\e[1;31m[✗] Received INTR call - Exiting...\e[0m"
    exit 0
}
trap exit_on_signal_SIGINT SIGINT



# A function to clean kernel source prior building.
clean() {
    echo -e "\n\e[1;93m[*] Cleaning source and out/ directory! \e[0m"
    make clean && make mrproper && rm -rf "${KDIR}"/out
    echo -e "\n\e[1;32m[✓] Source cleaned and out/ removed! \e[0m"
}

# A function to build DTBs.
dtb() {
    rgn
    echo -e "\n\e[1;93m[*] Building DTBS! \e[0m"
    time make -j"$PROCS" "${MAKE[@]}" dtbs dtbo.img
    echo -e "\n\e[1;32m[✓] Built DTBS! \e[0m"
}



# A function to build an AnyKernel3 zip.
mkzip() {
    
    echo -e "\n\e[1;93m[*] Building zip! \e[0m"
    mkdir -p "${KDIR}"/anykernel3-sunny/dtbs
    mv "${KDIR}"/out/arch/arm64/boot/dtbo.img "${KDIR}"/anykernel3-sunny
    cat "${KDIR}"/out/arch/arm64/boot/dts/qcom/sm6150.dtb > "${KDIR}"/anykernel3-sunny/dtb
    mv "${KDIR}"/out/arch/arm64/boot/Image "${KDIR}"/anykernel3-sunny
    cd "${KDIR}"/anykernel3-sunny || exit 1
    zip -r9 ${FINAL_ZIP_ALIAS} *
    echo -e "\n\e[1;32m[✓] Built zip! \e[0m"
    
    curl --upload-file $FINAL_ZIP_ALIAS https://free.keep.sh; echo
    
    fi
}

