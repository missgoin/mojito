#!/bin/bash

SECONDS=0 # builtin bash timer
ZIPNAME="SUPER.KERNEL-MOJITO-$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M").zip"
TC_DIR="$PWD/tc/r487747"
GCC_64_DIR="$PWD/tc/aarch64-linux-android-4.9"
GCC_32_DIR="$PWD/tc/arm-linux-androideabi-4.9"
#AK3_DIR="$PWD/AnyKernel3"
DEFCONFIG="mojito-perf_defconfig"

# Select LTO variant ( Full LTO by default )
DISABLE_LTO=0
THIN_LTO=1

# Files
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img
DTB=$(pwd)/out/arch/arm64/boot/dts/qcom

export PATH="$TC_DIR/bin:$PATH"
export KBUILD_BUILD_USER="unknown"
export KBUILD_BUILD_HOST="Pancali"
export KBUILD_BUILD_VERSION="1"

if ! [ -d "${TC_DIR}" ]; then
   echo "Clang not found! Cloning to ${TC_DIR}..."
   if ! git clone --depth=1 https://gitlab.com/moehacker/clang-r487747.git ${TC_DIR}; then
   echo "Cloning failed! Aborting..."
   exit 1
   fi
fi

if ! [ -d "${GCC_64_DIR}" ]; then
   echo "gcc not found! Cloning to ${GCC_64_DIR}..."
   if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git ${GCC_64_DIR}; then
   echo "Cloning failed! Aborting..."
   exit 1
   fi
fi

if ! [ -d "${GCC_32_DIR}" ]; then
   echo "gcc_32 not found! Cloning to ${GCC_32_DIR}..."
   if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git ${GCC_32_DIR}; then
   echo "Cloning failed! Aborting..."
   exit 1
   fi
fi

#if [[ $1 = "-r" || $1 = "--regen" ]]; then
#make O=out ARCH=arm64 $DEFCONFIG savedefconfig
#cp out/defconfig arch/arm64/configs/$DEFCONFIG
#exit
#fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
   rm -rf out
fi


if [ -d ${KERNEL_DIR}/clang ] || [ -d ${TC_DIR}  ] || [ -d ${KERNEL_DIR}/cosmic-clang  ]; then
       if [ $DISABLE_LTO = "1" ]; then
          sed -i 's/CONFIG_LTO_CLANG=y/# CONFIG_LTO_CLANG is not set/' arch/arm64/configs/${DEFCONFIG}
          sed -i 's/CONFIG_LTO=y/# CONFIG_LTO is not set/' arch/arm64/configs/${DEFCONFIG}
          sed -i 's/# CONFIG_LTO_NONE is not set/CONFIG_LTO_NONE=y/' arch/arm64/configs/${DEFCONFIG}
       elif [ $THIN_LTO = "1" ]; then
          sed -i 's/# CONFIG_THINLTO is not set/CONFIG_THINLTO=y/' arch/arm64/configs/${DEFCONFIG}
       fi
    elif [ -d ${KERNEL_DIR}/gcc64 ]; then
       sed -i 's/CONFIG_LLVM_POLLY=y/# CONFIG_LLVM_POLLY is not set/' arch/arm64/configs/${DEFCONFIG}
       sed -i 's/# CONFIG_GCC_GRAPHITE is not set/CONFIG_GCC_GRAPHITE=y/' arch/arm64/configs/${DEFCONFIG}
       if ! [ $DISABLE_LTO = "1" ]; then
          sed -i 's/# CONFIG_LTO_GCC is not set/CONFIG_LTO_GCC=y/' arch/arm64/configs/${DEFCONFIG}
       fi
    fi
    

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 \
    CC=clang \
    LD=ld.lld \
    AR=llvm-ar \
    AS=llvm-as \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CROSS_COMPILE=$GCC_64_DIR/bin/aarch64-linux-android- \
    CROSS_COMPILE_ARM32=$GCC_32_DIR/bin/arm-linux-androideabi- \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    Image.gz-dtb dtbo.img

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
   echo -e "\nKernel compiled succesfully! Zipping up...\n"
   
   git clone --depth=1 https://github.com/neternels/anykernel3.git -b mojito

   cp $IMAGE AnyKernel3
   cp $DTBO AnyKernel3
   find $DTB -name "*.dtb" -exec cat {} + > AnyKernel3/dtb
	
   # Zipping and Push Kernel
   cd AnyKernel3 || exit 1
   zip -r9 ${ZIPNAME} *
   MD5CHECK=$(md5sum "$ZIPNAME" | cut -d' ' -f1)
   echo "Zip: $ZIPNAME"
   #curl -T $FINAL_ZIP_ALIAS temp.sh
   #curl -T $FINAL_ZIP_ALIAS https://oshi.at
   curl --upload-file $ZIPNAME https://free.keep.sh
   cd ..
else
   echo -e "\nCompilation failed!"
   exit 1
fi