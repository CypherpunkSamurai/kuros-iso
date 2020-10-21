#!/bin/bash

sudo apt-get install debootstrap        \
                     squashfs-tools     \
                     xorriso            \
                     grub-pc-bin        \
                     grub-efi-amd64-bin \
                     mtools -y

# Remoção de arquivos de compilaçoes anteriores
sudo rm -rfv $HOME/bunturemix;mkdir -pv $HOME/bunturemix/chroot

# Criação do sistema base
sudo debootstrap \
    --arch=amd64 \
    --variant=minbase \
    --components=main,multiverse,universe \
    focal \
    $HOME/bunturemix/chroot
#    --include=fish \

# Primeira etapa da montagem do enjaulamento do sistema base
sudo mount --bind /dev $HOME/bunturemix/chroot/dev
sudo mount --bind /run $HOME/bunturemix/chroot/run
sudo chroot $HOME/bunturemix/chroot mount none -t proc /proc
sudo chroot $HOME/bunturemix/chroot mount none -t devpts /dev/pts
sudo chroot $HOME/bunturemix/chroot sh -c "export HOME=/root"
echo "bunturemix" | sudo tee $HOME/bunturemix/chroot/etc/hostname

# Adição dos repositórios principais do Ubuntu
cat <<EOF | sudo tee $HOME/bunturemix/chroot/etc/apt/sources.list
deb http://us.archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
EOF

# Additional repositories
#sudo chroot $HOME/bunturemix/chroot apt update
#sudo chroot $HOME/bunturemix/chroot apt install -y software-properties-common
# PPA 1


sudo chroot $HOME/bunturemix/chroot add-apt-repository -yn ppa:kubuntu-ppa/backports


# Second stage of caging assembly
sudo chroot $HOME/bunturemix/chroot apt update
sudo chroot $HOME/bunturemix/chroot apt install -y systemd-sysv
sudo chroot $HOME/bunturemix/chroot sh -c "dbus-uuidgen > /etc/machine-id"
sudo chroot $HOME/bunturemix/chroot ln -fs /etc/machine-id /var/lib/dbus/machine-id
sudo chroot $HOME/bunturemix/chroot dpkg-divert --local --rename --add /sbin/initctl
sudo chroot $HOME/bunturemix/chroot ln -s /bin/true /sbin/initctl

# Environment variables for automated script execution
sudo chroot $HOME/bunturemix/chroot sh -c "echo 'grub-pc grub-pc/install_devices_empty   boolean true' | debconf-set-selections"
sudo chroot $HOME/bunturemix/chroot sh -c "echo 'locales locales/locales_to_be_generated multiselect pt_BR.UTF-8 UTF-8' | debconf-set-selections"
sudo chroot $HOME/bunturemix/chroot sh -c "echo 'locales locales/default_environment_locale select pt_BR.UTF-8' | debconf-set-selections"
sudo chroot $HOME/bunturemix/chroot sh -c "echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections"
sudo chroot $HOME/bunturemix/chroot sh -c "echo 'resolvconf resolvconf/linkify-resolvconf boolean false' | debconf-set-selections"

# Ubuntu base tools
sudo chroot $HOME/bunturemix/chroot apt install -y --fix-missing \
    casper \
    discover \
    laptop-detect \
    linux-generic \
    locales \
    lupin-casper \
    net-tools \
    network-manager \
    os-prober \
    resolvconf \
    ubuntu-standard \
    wireless-tools \
    xorg 

# Programs included in the system without the recommended extras
sudo chroot $HOME/bunturemix/chroot apt install -y --no-install-recommends \
    plasma-desktop  


# Removing unnecessary packages
sudo chroot $HOME/bunturemix/chroot apt autoremove 

# System update
sudo chroot $HOME/bunturemix/chroot apt dist-upgrade -y

# Network reconfiguration
sudo chroot $HOME/bunturemix/chroot apt install --reinstall resolvconf
cat <<EOF | sudo tee $HOME/bunturemix/chroot/etc/NetworkManager/NetworkManager.conf
[main]
rc-manager=resolvconf
plugins=ifupdown,keyfile
dns=dnsmasq
[ifupdown]
managed=false
EOF
sudo chroot $HOME/bunturemix/chroot dpkg-reconfigure network-manager

# Dismantling the cage
sudo chroot $HOME/bunturemix/chroot truncate -s 0 /etc/machine-id
sudo chroot $HOME/bunturemix/chroot rm /sbin/initctl
sudo chroot $HOME/bunturemix/chroot dpkg-divert --rename --remove /sbin/initctl
sudo chroot $HOME/bunturemix/chroot apt clean
sudo chroot $HOME/bunturemix/chroot rm -rfv /tmp/* ~/.bash_history
sudo chroot $HOME/bunturemix/chroot umount /proc
sudo chroot $HOME/bunturemix/chroot umount /dev/pts
sudo chroot $HOME/bunturemix/chroot sh -c "export HISTSIZE=0"
sudo umount $HOME/bunturemix/chroot/dev
sudo umount $HOME/bunturemix/chroot/run

# GRUB configuration
echo "RESUME=none" | sudo tee $HOME/bunturemix/chroot/etc/initramfs-tools/conf.d/resume
echo "FRAMEBUFFER=y" | sudo tee $HOME/bunturemix/chroot/etc/initramfs-tools/conf.d/splash

# Brazilian Portuguese keyboard layout
sudo sed -i 's/us/br/g' $HOME/bunturemix/chroot/etc/default/keyboard

# Creating the installation image boot files
cd $HOME/bunturemix
mkdir -pv image/{boot/grub,casper,isolinux,preseed}
# Kernel
sudo cp chroot/boot/vmlinuz image/casper/vmlinuz
sudo cp chroot/boot/`ls -t1 chroot/boot/ |  head -n 1` image/casper/initrd
touch image/Ubuntu
# GRUB
cat <<EOF > image/isolinux/grub.cfg
search --set=root --file /Ubuntu
insmod all_video
set default="0"
set timeout=15

if loadfont /boot/grub/unicode.pf2 ; then
    insmod gfxmenu
	insmod jpeg
	insmod png
	set gfxmode=auto
	insmod efi_gop
	insmod efi_uga
	insmod gfxterm
	terminal_output gfxterm
fi

menuentry "KurOS Daily" {
   linux /casper/vmlinuz file=/cdrom/preseed/bunturemix.seed boot=casper quiet splash locale=pt_BR ---
   initrd /casper/initrd
}
EOF
# Loopback
cat <<EOF > image/boot/grub/loopback.cfg
menuentry "Unity XP(live-mode)" {
   linux /casper/vmlinuz file=/cdrom/preseed/bunturemix.seed boot=casper quiet splash iso-scan/filename=\${iso_path} locale=pt_BR ---
   initrd /casper/initrd
}
EOF
# Preesed
cat <<EOF > image/preseed/bunturemix.seed
# Success command
#d-i ubiquity/success_command string \
sed -i 's/quiet splash/quiet splash loglevel=0 logo.nologo vt.global_cursor_default=0/g' /target/etc/default/grub ; \
chroot /target update-grub
EOF
# Manifest files
sudo chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee image/casper/filesystem.manifest
sudo cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop
sudo sed -i '/ubiquity/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/casper/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/discover/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/laptop-detect/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/os-prober/d' image/casper/filesystem.manifest-desktop
#echo "\
#programa1 \
#programa2 \
#programa3" | sudo tee image/casper/filesystem.manifest-remove
# SquashFS
sudo mksquashfs chroot image/casper/filesystem.squashfs -comp xz
printf $(sudo du -sx --block-size=1 chroot | cut -f1) > image/casper/filesystem.size
# Disk definitions
cat <<EOF > image/README.diskdefines
#define DISKNAME  KUROS
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  amd64
#define ARCHamd64  1
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
EOF

# Generation of GRUB for installation image
cd $HOME/bunturemix/image
grub-mkstandalone \
   --format=x86_64-efi \
   --output=isolinux/bootx64.efi \
   --locales="" \
   --fonts="" \
   "boot/grub/grub.cfg=isolinux/grub.cfg"
(
   cd isolinux && \
   dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
   sudo mkfs.vfat efiboot.img && \
   mmd -i efiboot.img efi efi/boot && \
   mcopy -i efiboot.img ./bootx64.efi ::efi/boot/
)
grub-mkstandalone \
   --format=i386-pc \
   --output=isolinux/core.img \
   --install-modules="linux16 linux normal iso9660 biosdisk memdisk search tar ls" \
   --modules="linux16 linux normal iso9660 biosdisk search" \
   --locales="" \
   --fonts="" \
   "boot/grub/grub.cfg=isolinux/grub.cfg"
cat /usr/lib/grub/i386-pc/cdboot.img isolinux/core.img > isolinux/bios.img

# Generation of the internal MD5 of the installation image
sudo /bin/bash -c '(find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt)'

# Compiling the installation image
mkdir -pv ../iso
sudo xorriso \
   -as mkisofs \
   -iso-level 3 \
   -full-iso9660-filenames \
   -volid "KurOS_Daily" \
   -eltorito-boot boot/grub/bios.img \
   -no-emul-boot \
   -boot-load-size 4 \
   -boot-info-table \
   --eltorito-catalog boot/grub/boot.cat \
   --grub2-boot-info \
   --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
   -eltorito-alt-boot \
   -e EFI/efiboot.img \
   -no-emul-boot \
   -append_partition 2 0xef isolinux/efiboot.img \
   -output "../iso/bunturemix-19.10-amd64.iso" \
   -graft-points \
      "." \
      /boot/grub/bios.img=isolinux/bios.img \
      /EFI/efiboot.img=isolinux/efiboot.img

# Generation of external MD5 of the installation image.
md5sum ../iso/bunturemix-19.10-amd64.iso > ../iso/bunturemix-19.10-amd64.md5


export REPO_SLUG=$(echo -n $GITHUB_REPOSITORY_URL)

#wget -q "https://raw.githubusercontent.com/probonopd/uploadtool/master/upload.sh"

bash upload.sh ../iso/bunturemix-19.10-amd64.iso
