#!/bin/bash

## Pass to the function you want to run a "1"; for example BASE=1
## Change your User Input variables under to get everyhing well installed
BASE=

## After the base install was sucesfull reboot and pass to POST_INSTALL=1
POST_INSTALL=

base() {

# (Variables) User input
LUKS_PASSWORD=""
USERNAME=""
USER_PASSWORD=""
HOSTNAME=""
TIMEZONE=""
DISK=""

read -p "LUKS password: " LUKS_PASSWORD
read -p "Username: " USERNAME
read -p "User password: " USER_PASSWORD
read -p "Hostname: " HOSTNAME
read -p "Timezone (timedatectl list-timezones): " TIMEZONE

# (Variables) CPU vendor
if [[ $(cat /proc/cpuinfo | grep vendor | uniq) =~ "AuthenticAMD" ]]
then
 CPU_MICROCODE="amd-ucode"
elif [[ $(cat /proc/cpuinfo | grep vendor | uniq) =~ "GenuineIntel" ]]
then
 CPU_MICROCODE="intel-ucode"
fi

# Update system clock
timedatectl set-ntp true

# Sync packages database
pacman -Sy --noconfirm

# Zero out all GPT data structures
dd if=/dev/zero of="$DISK" bs=512 count=1
wipefs -af "$DISK"
sgdisk -Zo "$DISK"

# Create partition tables (sgdisk -L)
sgdisk -og $DISK
sgdisk --new 1:4096:+512M --typecode 1:ef00 --change-name 1:"EFI System Partition" $DISK
ENDSECTOR=$(sgdisk -E $DISK)
sgdisk --new 2:0:"$ENDSECTOR" --typecode 2:8309 --change-name 2:"Root Partition" $DISK
partprobe "$DISK"

# Prepare root partition: encrypt root partition and create bcachefs filesystem
echo "$LUKS_PASSWORD" | cryptsetup luksFormat /dev/nvme0n1p2
echo "$LUKS_PASSWORD" | cryptsetup open /dev/nvme0n1p2 root
bcachefs format /dev/mapper/root
mount /dev/mapper/root /mnt

# Prepare boot partition: create fat32 filesystem
mkfs.fat -F32 /dev/nvme0n1p1
mount --mkdir /dev/nvme0n1p1 /mnt/boot

# Install Arch Linux
pacstrap /mnt base base-devel linux-cachyos linux-cachyos-headers bcachefs-tools-git systemd-boot-manager linux-firmware efibootmgr amd-ucode intel-ucode apparmor networkmanager

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Configure system
arch-chroot /mnt /bin/bash << EOF
# Set system clock
timedatectl set-ntp true
ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
hwclock --systohc
# Set locales
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
locale-gen
# Add persistent keymap
echo "KEYMAP=de" > /etc/vconsole.conf
# Set hostname
echo $HOSTNAME > /etc/hostname
# Create new user
useradd -m -G wheel -s /bin/bash $USERNAME
echo -en "$USER_PASSWORD\n$USER_PASSWORD" | passwd $USERNAME
# Generate initramfs
sed -i 's/^HOOKS.*/HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems fsck bcachefs)/' /etc/mkinitcpio.conf
mkinitcpio -P
# Setup systemd-boot
bootctl --path=/boot install
tee /boot/loader/loader.conf << END
default linux-cachyos.conf
timeout 10
console-mode max
editor no
END
sdboot-manage gen
# Setup Pacman hook for automatic systemd-boot updates
mkdir -p /etc/pacman.d/hooks/
tee /etc/pacman.d/hooks/systemd-boot.hook << END
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd
[Action]
Description = Updating systemd-boot
When = PostTransaction
Exec = /usr/bin/systemctl restart systemd-boot-update.service
END
# Enable periodic TRIM
systemctl enable fstrim.timer
# Enable NetworkManager service
systemctl enable NetworkManager.service
# Enable Apparmor service
systemctl enable apparmor.service
# Install and configure sudo
echo '%wheel ALL=(ALL) ALL' | EDITOR='tee -a' visudo
exit
EOF

echo "you can chroot into the system with arch-chroot /mnt or exit with umount -R /mnt"

echo "CachyOS bcachefs is ready. You can reboot now!"

}

post_install() {

# Detect username
username=$(whoami)

#echo "Adding multilib support"
sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

wget https://build.cachyos.org/cachyos-repo.tar.xz
tar xvf cachyos-repo.tar.xz
cd cachyos-repo
sudo ./cachyos-repo.sh
echo "Syncing repos and updating packages"
sudo pacman -Suuy --noconfirm

echo "Installing and configuring UFW"
sudo pacman -S --noconfirm ufw
sudo systemctl enable ufw
sudo systemctl start ufw
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "Installing GPU drivers"
sudo pacman -S --noconfirm mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader llvm llvm-libs lib32-llvm lib32-clang

echo "Improving hardware video accelaration"
sudo pacman -S --noconfirm ffmpeg libva-utils libva-vdpau-driver vdpauinfo

echo "Installing common applications"
sudo pacman -S --noconfirm micro git openssh links upower htop powertop p7zip ripgrep unzip fwupd unrar

echo "Creating user's folders"
sudo pacman -S --noconfirm xdg-user-dirs

echo "Installing fonts"
sudo pacman -S --noconfirm ttf-roboto ttf-roboto-mono ttf-droid ttf-opensans ttf-dejavu ttf-liberation ttf-hack noto-fonts ttf-fira-code ttf-fira-mono ttf-font-awesome noto-fonts-emoji ttf-hanazono adobe-source-code-pro-fonts ttf-cascadia-code inter-font

sudo pacman -S --noconfirm nvidia nvidia-utils nvidia-dkms paru

echo "Installing and configuring Plymouth"
paru -S --noconfirm plymouth
sudo sed -i 's/base systemd autodetect/base systemd sd-plymouth autodetect/g' /etc/mkinitcpio.conf
sudo mkinitcpio -p
sudo plymouth-set-default-theme -R bgrt

echo "Reducing VM writeback time"
sudo touch /etc/sysctl.d/dirty.conf
sudo tee -a /etc/sysctl.d/dirty.conf << EOF
vm.dirty_writeback_centisecs = 1500
EOF
fi

echo "Disabling root (still allows sudo)"
passwd --lock root

echo "Adding NTFS support"
sudo pacman -S --noconfirm ntfs-3g

echo "Installing pipewire multimedia framework"
sudo pacman -S --noconfirm pipewire pipewire-alsa pipewire-pulse pipewire-jack lib32-pipewire lib32-pipewire-jack

echo "Installing Xorg"
sudo pacman -S --noconfirm xorg

echo "Installing Plasma and common applications"
sudo pacman -S --noconfirm plasma ark dolphin dolphin-plugins gwenview kate kgpg konsole kwalletmanager okular spectacle kscreen plasma-browser-integration kcalc filelight partitionmanager krunner kfind plasma-workspace plasma-framework plasma-integration cachyos-kde-settings


echo "Adding Thunderbolt frontend"
sudo pacman -S --noconfirm plasma-thunderbolt

echo "Improve Discover support"
sudo pacman -S --noconfirm packagekit-qt5

echo "Installing Plasma wayland session"
sudo pacman -S --noconfirm plasma-wayland-session

echo "Installing SDDM and SDDM-KCM"
sudo pacman -S --noconfirm sddm sddm-kcm
sudo systemctl enable sddm

echo "Improving multimedia support"
sudo pacman -S --noconfirm phonon-qt5-vlc

echo "Disabling baloo (file indexer)"
balooctl suspend
balooctl disable

echo "Improving KDE/GTK integration"
sudo pacman -S --noconfirm xdg-desktop-portal xdg-desktop-portal-kde breeze-gtk kde-gtk-config

echo "Your setup is ready. You can reboot now!"

}

## Base
if [ ${BASE} = 1 ]; then
    base
fi

## Stage 2
if [ ${POST_INSTALL} = 1 ]; then
    post_install
fi
