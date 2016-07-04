#!/bin/bash

export PATH=/home/nixo/pi2/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin:$PATH

cd linux
export KERNEL=kernel7


#export PREFIX=/home/nixo/pi2/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/libexec/gcc/arm-linux-gnueabihf-


#                              tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/libexec/gcc/arm-linux-gnueabihf/4.8.3/cc1

export  CCPREFIX=/home/nixo/pi2/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin/arm-linux-gnueabihf-

make -j9 ARCH=arm CROSS_COMPILE=$CCPREFIX bcm2709_defconfig

make -j9 ARCH=arm CROSS_COMPILE=$CCPREFIX zImage modules dtbs

sshfs root@pi2:/ /home/nixo/pi2/pi2root

make ARCH=arm CROSS_COMPILE=$CCPREFIX INSTALL_MOD_PATH=/home/nixo/pi2/pi2root modules_install

cp /home/nixo/pi2/pi2root/boot/$KERNEL.img /home/nixo/pi2/pi2root/boot/$KERNEL.img.bak

scripts/mkknlimg arch/arm/boot/zImage /home/nixo/pi2/pi2root/boot/$KERNEL.img

cp arch/arm/boot/dts/*.dtb /home/nixo/pi2/pi2root/boot/
cp arch/arm/boot/dts/overlays/*.dtb* /home/nixo/pi2/pi2root/boot/overlays/
cp arch/arm/boot/dts/overlays/README /home/nixo/pi2/pi2root/boot/overlays/

umount /home/nixo/pi2/pi2root
