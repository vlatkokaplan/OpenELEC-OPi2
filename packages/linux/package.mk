################################################################################
#      This file is part of OpenELEC - http://www.openelec.tv
#      Copyright (C) 2009-2016 Stephan Raue (stephan@openelec.tv)
#
#  OpenELEC is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 2 of the License, or
#  (at your option) any later version.
#
#  OpenELEC is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with OpenELEC.  If not, see <http://www.gnu.org/licenses/>.
################################################################################

PKG_NAME="linux"
PKG_REV="1"
PKG_ARCH="any"
PKG_LICENSE="GPL"
PKG_SITE="http://www.kernel.org"
PKG_DEPENDS_HOST="ccache:host"
PKG_DEPENDS_TARGET="toolchain cpio:host kmod:host pciutils xz:host wireless-regdb keyutils"
PKG_DEPENDS_INIT="toolchain cpu-firmware:init"
PKG_NEED_UNPACK="$LINUX_DEPENDS"
PKG_PRIORITY="optional"
PKG_SECTION="linux"
PKG_SHORTDESC="linux26: The Linux kernel 2.6 precompiled kernel binary image and modules"
PKG_LONGDESC="This package contains a precompiled kernel image and the modules."
case "$LINUX" in
  amlogic)
    PKG_VERSION="amlogic-3.10-c8d5b2f"
    PKG_URL="$DISTRO_SRC/$PKG_NAME-$PKG_VERSION.tar.xz"
    ;;
  imx6)
    PKG_VERSION="cuboxi-3.14-ea83bda"
    PKG_URL="$DISTRO_SRC/$PKG_NAME-$PKG_VERSION.tar.xz"
    PKG_DEPENDS_TARGET="$PKG_DEPENDS_TARGET imx6-status-led imx6-soc-fan"
    ;;
  awh3)
    PKG_VERSION="awh3-3.4"
    PKG_URL="https://github.com/jernejsk/OpenELEC-OPi2/raw/7de19646f7a8bf77df6f2f40fff7aa978f9beb67/storage/$PKG_NAME-$PKG_VERSION.tar.xz"
    ;;
  *)
    PKG_VERSION="4.4.6"
    PKG_URL="http://www.kernel.org/pub/linux/kernel/v4.x/$PKG_NAME-$PKG_VERSION.tar.xz"
    ;;
esac

PKG_IS_ADDON="no"
PKG_AUTORECONF="no"

PKG_MAKE_OPTS_HOST="ARCH=$TARGET_KERNEL_ARCH headers_check"

if [ "$BUILD_ANDROID_BOOTIMG" = "yes" ]; then
  PKG_DEPENDS_TARGET="$PKG_DEPENDS_TARGET mkbootimg:host"
fi

post_patch() {
  if [ -n "$DEVICE" -a -f $PROJECT_DIR/$PROJECT/devices/$DEVICE/$PKG_NAME/$PKG_NAME.$TARGET_ARCH.conf ]; then
    KERNEL_CFG_FILE=$PROJECT_DIR/$PROJECT/devices/$DEVICE/$PKG_NAME/$PKG_NAME.$TARGET_ARCH.conf
  elif [ -f $PROJECT_DIR/$PROJECT/$PKG_NAME/$PKG_NAME.$TARGET_ARCH.conf ]; then
    KERNEL_CFG_FILE=$PROJECT_DIR/$PROJECT/$PKG_NAME/$PKG_NAME.$TARGET_ARCH.conf
  else
    KERNEL_CFG_FILE=$PKG_DIR/config/$PKG_NAME.$TARGET_ARCH.conf
  fi

  sed -i -e "s|^HOSTCC[[:space:]]*=.*$|HOSTCC = $HOST_CC|" \
         -e "s|^HOSTCXX[[:space:]]*=.*$|HOSTCXX = $HOST_CXX|" \
         -e "s|^ARCH[[:space:]]*?=.*$|ARCH = $TARGET_KERNEL_ARCH|" \
         -e "s|^CROSS_COMPILE[[:space:]]*?=.*$|CROSS_COMPILE = $TARGET_PREFIX|" \
         $PKG_BUILD/Makefile

  cp $KERNEL_CFG_FILE $PKG_BUILD/.config
  if [ ! "$BUILD_ANDROID_BOOTIMG" = "yes" ]; then
    sed -i -e "s|^CONFIG_INITRAMFS_SOURCE=.*$|CONFIG_INITRAMFS_SOURCE=\"$ROOT/$BUILD/image/initramfs.cpio\"|" $PKG_BUILD/.config
  fi

  # set default hostname based on $DISTRONAME
    sed -i -e "s|@DISTRONAME@|$DISTRONAME|g" $PKG_BUILD/.config

  # disable swap support if not enabled
  if [ ! "$SWAP_SUPPORT" = yes ]; then
    sed -i -e "s|^CONFIG_SWAP=.*$|# CONFIG_SWAP is not set|" $PKG_BUILD/.config
  fi

  # disable nfs support if not enabled
  if [ ! "$NFS_SUPPORT" = yes ]; then
    sed -i -e "s|^CONFIG_NFS_FS=.*$|# CONFIG_NFS_FS is not set|" $PKG_BUILD/.config
  fi

  # disable cifs support if not enabled
  if [ ! "$SAMBA_SUPPORT" = yes ]; then
    sed -i -e "s|^CONFIG_CIFS=.*$|# CONFIG_CIFS is not set|" $PKG_BUILD/.config
  fi

  # disable iscsi support if not enabled
  if [ ! "$ISCSI_SUPPORT" = yes ]; then
    sed -i -e "s|^CONFIG_SCSI_ISCSI_ATTRS=.*$|# CONFIG_SCSI_ISCSI_ATTRS is not set|" $PKG_BUILD/.config
    sed -i -e "s|^CONFIG_ISCSI_TCP=.*$|# CONFIG_ISCSI_TCP is not set|" $PKG_BUILD/.config
    sed -i -e "s|^CONFIG_ISCSI_BOOT_SYSFS=.*$|# CONFIG_ISCSI_BOOT_SYSFS is not set|" $PKG_BUILD/.config
    sed -i -e "s|^CONFIG_ISCSI_IBFT_FIND=.*$|# CONFIG_ISCSI_IBFT_FIND is not set|" $PKG_BUILD/.config
    sed -i -e "s|^CONFIG_ISCSI_IBFT=.*$|# CONFIG_ISCSI_IBFT is not set|" $PKG_BUILD/.config
  fi

  # copy some extra firmware to linux tree
  cp -R $PKG_DIR/firmware/* $PKG_BUILD/firmware

  make -C $PKG_BUILD oldconfig
}

makeinstall_host() {
  make ARCH=$TARGET_KERNEL_ARCH INSTALL_HDR_PATH=dest headers_install
  mkdir -p $SYSROOT_PREFIX/usr/include
    cp -R dest/include/* $SYSROOT_PREFIX/usr/include
}

pre_make_target() {
  # regdb
  cp $(get_build_dir wireless-regdb)/db.txt $ROOT/$PKG_BUILD/net/wireless/db.txt

  if [ "$BOOTLOADER" = "u-boot" ]; then
    ( cd $ROOT
      $SCRIPTS/build u-boot
    )
  fi
}

make_target() {
  LDFLAGS="" make modules
  LDFLAGS="" make INSTALL_MOD_PATH=$INSTALL DEPMOD="$ROOT/$TOOLCHAIN/bin/depmod" modules_install
  
  if [ "$LINUX" = "awh3" ]; then
    LDFLAGS="" make -C modules/mali/DX910-SW-99002-r4p0-00rel0/driver/src/devicedrv/ump \
         V=1 \
         ARCH=$TARGET_ARCH \
         CONFIG=ca8-virtex820-m400-1 \
         BUILD=release \
         KDIR=$(kernel_path) \
         CROSS_COMPILE=$TARGET_PREFIX
    LDFLAGS="" make -C modules/mali/DX910-SW-99002-r4p0-00rel0/driver/src/devicedrv/mali \
         V=1 \
         ARCH=$TARGET_ARCH \
         USING_MMU=1 \
         USING_UMP=1 \
         USING_PMM=1 \
         BUILD=release \
         KDIR=$(kernel_path) \
         CROSS_COMPILE=$TARGET_PREFIX
    mkdir -p $INSTALL/lib/modules/$(get_module_dir)/kernel/drivers/video
    cp modules/mali/DX910-SW-99002-r4p0-00rel0/driver/src/devicedrv/ump/ump.ko \
      $INSTALL/lib/modules/$(get_module_dir)/kernel/drivers/video
    cp modules/mali/DX910-SW-99002-r4p0-00rel0/driver/src/devicedrv/mali/mali.ko \
      $INSTALL/lib/modules/$(get_module_dir)/kernel/drivers/video
  fi
  
  rm -f $INSTALL/lib/modules/*/build
  rm -f $INSTALL/lib/modules/*/source

  ( cd $ROOT
    rm -rf $ROOT/$BUILD/initramfs
    $SCRIPTS/install initramfs
  )

  if [ "$BOOTLOADER" = "u-boot" -a -n "$KERNEL_UBOOT_EXTRA_TARGET" ]; then
    for extra_target in "$KERNEL_UBOOT_EXTRA_TARGET"; do
      LDFLAGS="" make $extra_target
    done
  fi

  LDFLAGS="" make $KERNEL_TARGET $KERNEL_MAKE_EXTRACMD

  if [ "$BUILD_ANDROID_BOOTIMG" = "yes" ]; then
    LDFLAGS="" mkbootimg --kernel arch/$TARGET_KERNEL_ARCH/boot/$KERNEL_TARGET --ramdisk $ROOT/$BUILD/image/initramfs.cpio \
      --second "$ANDROID_BOOTIMG_SECOND" --output arch/$TARGET_KERNEL_ARCH/boot/boot.img
    mv -f arch/$TARGET_KERNEL_ARCH/boot/boot.img arch/$TARGET_KERNEL_ARCH/boot/$KERNEL_TARGET
  fi
}

makeinstall_target() {
  if [ "$BOOTLOADER" = "u-boot" ]; then
    mkdir -p $INSTALL/usr/share/bootloader
    for dtb in arch/$TARGET_KERNEL_ARCH/boot/dts/*.dtb; do
      cp $dtb $INSTALL/usr/share/bootloader 2>/dev/null || :
    done
  elif [ "$BOOTLOADER" = "bcm2835-firmware" ]; then
    mkdir -p $INSTALL/usr/share/bootloader/overlays
    cp -p arch/$TARGET_KERNEL_ARCH/boot/dts/*.dtb $INSTALL/usr/share/bootloader
    for dtb in arch/$TARGET_KERNEL_ARCH/boot/dts/overlays/*.dtbo; do
      cp $dtb $INSTALL/usr/share/bootloader/overlays 2>/dev/null || :
    done
    cp -p arch/$TARGET_KERNEL_ARCH/boot/dts/overlays/README $INSTALL/usr/share/bootloader/overlays
  fi
}

make_init() {
 : # reuse make_target()
}

makeinstall_init() {
  if [ -n "$INITRAMFS_MODULES" ]; then
    mkdir -p $INSTALL/etc
    mkdir -p $INSTALL/lib/modules

    for i in $INITRAMFS_MODULES; do
      module=`find .install_pkg/lib/modules/$(get_module_dir)/kernel -name $i.ko`
      if [ -n "$module" ]; then
        echo $i >> $INSTALL/etc/modules
        cp $module $INSTALL/lib/modules/`basename $module`
      fi
    done
  fi

  if [ "$UVESAFB_SUPPORT" = yes ]; then
    mkdir -p $INSTALL/lib/modules
      uvesafb=`find .install_pkg/lib/modules/$(get_module_dir)/kernel -name uvesafb.ko`
      cp $uvesafb $INSTALL/lib/modules/`basename $uvesafb`
  fi
}

post_install() {
  mkdir -p $INSTALL/lib/firmware/
    ln -sf /storage/.config/firmware/ $INSTALL/lib/firmware/updates

  # bluez looks in /etc/firmware/
    ln -sf /lib/firmware/ $INSTALL/etc/firmware
}
