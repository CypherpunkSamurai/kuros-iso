#!/bin/bash


sudo apt-get install debootstrap        \
                     squashfs-tools     \
                     xorriso            \
                     grub-pc-bin        \
                     grub-efi-amd64-bin \
                     mtools -y

mkdir -p $HOME/LIVE_BOOT/chroot

sudo debootstrap --arch=amd64                     \
                 --variant=minbase                \
                 buster                           \
                 $HOME/LIVE_BOOT/chroot           \
                 http://ftp.us.debian.org/debian/
                 
sudo chroot $HOME/LIVE_BOOT/chroot bash -c 'echo "debian-live" > /etc/hostname'
sudo chroot $HOME/LIVE_BOOT/chroot apt-get update
sudo chroot $HOME/LIVE_BOOT/chroot apt-get -y --no-install-recommends install linux-image-4.19.0-8-amd64 live-boot systemd-sysv
                 
mkdir -p $HOME/LIVE_BOOT/{buster,image/live}

sudo mksquashfs                                    \
    $HOME/LIVE_BOOT/chroot                         \
    $HOME/LIVE_BOOT/image/live/filesystem.squashfs \
    -e boot

cp $HOME/LIVE_BOOT/chroot/boot/vmlinuz-* $HOME/LIVE_BOOT/image/vmlinuz
cp $HOME/LIVE_BOOT/chroot/boot/initrd.img-* $HOME/LIVE_BOOT/image/initrd

cat <<'EOF' >$HOME/LIVE_BOOT/buster/grub.cfg

insmod all_video

search --set=root --file /KUROS

set default="0"
set timeout=30

menuentry "KurOS" {
    linux /vmlinuz boot=live quiet nomodeset
    initrd /initrd
}
EOF

touch $HOME/LIVE_BOOT/image/KUROS

grub-mkstandalone                                          \
    --format=x86_64-efi                                    \
    --output=$HOME/LIVE_BOOT/buster/bootx64.efi            \
    --locales=""                                           \
    --fonts=""                                             \
    "boot/grub/grub.cfg=$HOME/LIVE_BOOT/buster/grub.cfg"

(cd $HOME/LIVE_BOOT/buster &&                         \
    dd if=/dev/zero of=efiboot.img bs=1M count=10 &&  \
    mkfs.vfat efiboot.img &&                          \
    mmd -i efiboot.img efi efi/boot &&                \
    mcopy -i efiboot.img ./bootx64.efi ::efi/boot/
)

grub-mkstandalone                                                           \
    --format=i386-pc                                                        \
    --output=$HOME/LIVE_BOOT/buster/core.img                               \
    --install-modules="linux normal iso9660 biosdisk memdisk search tar ls" \
    --modules="linux normal iso9660 biosdisk search"                        \
    --locales=""                                                            \
    --fonts=""                                                              \
    "boot/grub/grub.cfg=$HOME/LIVE_BOOT/buster/grub.cfg"

cat                                  \
    /usr/lib/grub/i386-pc/cdboot.img \
    $HOME/LIVE_BOOT/buster/core.img \
  > $HOME/LIVE_BOOT/buster/bios.img

xorriso \
    -as mkisofs                                                     \
    -iso-level 3                                                    \
    -full-iso9660-filenames                                         \
    -volid "KUROS_DAILY"                                            \
    -eltorito-boot                                                  \
        boot/grub/bios.img                                          \
        -no-emul-boot                                               \
        -boot-load-size 4                                           \
        -boot-info-table                                            \
        --eltorito-catalog boot/grub/boot.cat                       \
    --grub2-boot-info                                               \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img               \
    -eltorito-alt-boot                                              \
        -e EFI/efiboot.img                                          \
        -no-emul-boot                                               \
    -append_partition 2 0xef ${HOME}/LIVE_BOOT/buster/efiboot.img   \
    -output "${HOME}/LIVE_BOOT/KurOS_daily.iso"                     \
    -graft-points                                                   \
        "${HOME}/LIVE_BOOT/image"                                   \
        /boot/grub/bios.img=$HOME/LIVE_BOOT/buster/bios.img         \
        /EFI/efiboot.img=$HOME/LIVE_BOOT/buster/efiboot.img

wget -q "https://raw.githubusercontent.com/probonopd/uploadtool/master/upload.sh"
bash upload.sh "${HOME}/LIVE_BOOT/KurOS_daily.iso"


