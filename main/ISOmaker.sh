#!/bin/bash

# linux-lumi.os - Stage 6 (Revised): Creating ISO for live-boot
# هذا السكربت يقوم بتجميع الـ ISO ليتوافق مع حزمة live-boot القياسية

set -e

WORKING_DIR="$(pwd)/lumi-build"
ROOTFS_DIR="$WORKING_DIR/rootfs"
OUTPUT_DIR="$WORKING_DIR/output"
ISO_ROOT="$WORKING_DIR/iso_root"

echo "----------------------------------------------------"
echo "  Stage 6 (Revised): Building ISO for live-boot"
echo "----------------------------------------------------"

# 1. التأكد من وجود الأدوات اللازمة
echo "Checking ISO build tools..."
sudo apt-get update && sudo apt-get install -y \
    xorriso \
    squashfs-tools \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools

# 2. إنشاء هيكلية مجلد الـ ISO المتوافقة مع live-boot
echo "Preparing ISO root structure..."
rm -rf "$ISO_ROOT"
mkdir -p "$ISO_ROOT"/{boot/grub,live}

# 3. ضغط نظام الملفات الجذري (SquashFS) ووضعه في مجلد /live
echo "Compressing RootFS into /live/filesystem.squashfs..."
# ملاحظة: live-boot يبحث عن filesystem.squashfs داخل مجلد /live حصراً
sudo mksquashfs "$ROOTFS_DIR" "$ISO_ROOT/live/filesystem.squashfs" -comp xz -Xbcj x86 -Xdict-size 100% -e boot

# 4. استخراج النواة والـ Initramfs القياسي المستقر وصريح التسمية
echo "Copying Kernel and live-boot Initramfs from RootFS..."
KERNEL_FILE="$ROOTFS_DIR/boot/vmlinuz-6.12.86+deb13-amd64"
INITRD_FILE="$ROOTFS_DIR/boot/initrd.img-6.12.86+deb13-amd64"

if [ ! -f "$KERNEL_FILE" ] || [ ! -f "$INITRD_FILE" ]; then
    echo "Error: Debian Kernel or Initrd not found in boot folder!"
    exit 1
else
    echo "Using Verified Kernel: $KERNEL_FILE"
    echo "Using Verified Initrd: $INITRD_FILE"
    cp "$KERNEL_FILE" "$ISO_ROOT/live/vmlinuz"
    cp "$INITRD_FILE" "$ISO_ROOT/live/initrd.img"
fi
# 5. إنشاء ملف تكوين GRUB 2 (grub.cfg) مع معاملات تشغيل واضحة
echo "Creating GRUB configuration with boot=live..."
cat << 'EOF' > "$ISO_ROOT/boot/grub/grub.cfg"
set default=0
set timeout=5

insmod all_video
if loadfont unicode ; then
  set gfxmode=1024x768
  insmod gfxterm
  terminal_output gfxterm
fi

menuentry "Start LumiOS GNU/Linux 0.1 (First Boot Setup)" {
    echo "Loading LumiOS Setup Wizard..."
    linux /live/vmlinuz boot=live components live-config.components=none oem-config/enable=true quiet splash
    initrd /live/initrd.img
}

menuentry "Start LumiOS GNU/Linux (Safe Mode)" {
    echo "Loading LumiOS in Safe Mode..."
    linux /live/vmlinuz boot=live components live-config.components=none oem-config/enable=true nomodeset
    initrd /live/initrd.img
}
EOF
# 6. صناعة الـ ISO الهجين النهائي
echo "Generating final Hybrid ISO image..."
grub-mkrescue -o "$OUTPUT_DIR/linux-lumi-0.1.iso" "$ISO_ROOT"

# 7. التحقق من النتيجة النهائية
if [ -f "$OUTPUT_DIR/linux-lumi-0.1.iso" ]; then
    echo "----------------------------------------------------"
    echo "  SUCCESS! linux-lumi.os ISO (Live-Boot version) is ready."
    echo "  Location: $OUTPUT_DIR/linux-lumi-0.1.iso"
    echo "  Size: $(du -h "$OUTPUT_DIR/linux-lumi-0.1.iso" | cut -f1)"
    echo "----------------------------------------------------"
else
    echo "Error: Failed to generate ISO image."
    exit 1
fi

echo "Done."
