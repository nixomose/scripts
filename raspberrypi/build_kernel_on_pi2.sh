#!/bin/bash

echo "run this script as root in an empty directory on a raspberry pi2."
echo "this script will compile a raspberry pi2 kernel on the pi itself."

git clone --depth=1 https://github.com/raspberrypi/linux

apt-get install bc


cd linux
export KERNEL=kernel7
make -j5 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- bcm2709_defconfig

make -j5 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage modules dtbs
 
make -j5 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=/ modules_install

cp /boot/$KERNEL.img /boot/$KERNEL.img.bak

scripts/mkknlimg arch/arm/boot/zImage /boot/$KERNEL.img

cp arch/arm/boot/dts/*.dtb /boot/
cp arch/arm/boot/dts/overlays/*.dtb* /boot/overlays/
cp arch/arm/boot/dts/overlays/README /boot/overlays/

echo all done.
