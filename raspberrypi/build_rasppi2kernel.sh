#!/bin/bash

echo "run this script as root in an empty directory."
echo "this script will cross compile a raspberry pi2 kernel on an ubuntu machine."

your_raspberry_pi2_hostname=pi2

git clone --depth=1 https://github.com/raspberrypi/linux

apt-get install bc

git clone https://github.com/raspberrypi/tools

cd linux
export KERNEL=kernel7



export  CCPREFIX=../tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin/arm-linux-gnueabihf-

make -j9 ARCH=arm CROSS_COMPILE=$CCPREFIX bcm2709_defconfig

make -j9 ARCH=arm CROSS_COMPILE=$CCPREFIX zImage modules dtbs

mkdir -p ../pi2root

sshfs root@$your_raspberry_pi2_hostname:/ ../pi2root

make ARCH=arm CROSS_COMPILE=$CCPREFIX INSTALL_MOD_PATH=../pi2root modules_install

cp ../pi2root/boot/$KERNEL.img ../pi2root/boot/$KERNEL.img.bak

scripts/mkknlimg arch/arm/boot/zImage ../pi2root/boot/$KERNEL.img

cp arch/arm/boot/dts/*.dtb ../pi2root/boot/
cp arch/arm/boot/dts/overlays/*.dtb* ../pi2root/boot/overlays/
cp arch/arm/boot/dts/overlays/README ../pi2root/boot/overlays/

fusermount -u ../pi2root
