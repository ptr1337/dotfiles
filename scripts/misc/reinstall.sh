#!/bin/bash

AUR=/home/ptr1337/projects/kernel/aur
PROJECTS=/home/ptr1337/projects
REPO=/home/ptr1337/repo
paru -S llvm clang lld llvm-libs compiler-rt bitwarden cpu-x-git bleachbit makepkg-optimize-mold meld smartgit thunderbird zsh xlayoutdisplay beautysh autopep8 shellcheck micro zenmonitor3-git zsh

echo  "Create directorys"
mkdir -p $PROJECTS
mkdir -p $AUR
mkdir $PROJECTS/kernel
mkdir $PROJECTS/cachyos
cd $REPO
git clone git@github.com:CachyOS/linux-cachyos.git
git clone git@github.com:ptr1337/toolchain.git
cd $HOME
cd $PROJECTS/cachyos
echo  "Clone CachyOS stuff"
git clone git@github.com:CachyOS/CachyOS-Live-ISO.git
git clone git@github.com:CachyOS/CachyOS-PKGBUILDS.git
git clone git@github.com:CachyOS/CachyOS-Browser-Common.git
git clone git@github.com:CachyOS/CachyOS-Browser-Settings.git
git clone git@github.com:CachyOS/CachyOS-Settings.git
git clone git@github.com:CachyOS/cachyos-calamares.git
git clone git@github.com:CachyOS/New-Cli-Installer.git
git clone git@github.com:CachyOS/ananicy-rules.git
git clone git@github.com:CachyOS/zfs.git
git clone git@github.com:CachyOS/website.git
git clone git@github.com:CachyOS/cachyos-fish-config.git
git clone git@github.com:CachyOS/cachyos-zsh-config.git
git clone git@github.com:CachyOS/cachyos-kde-settings.git

cd $PROJECTS/kernel
echo  "Clone kernel stuff"
git clone git@github.com:CachyOS/linux.git
git clone git@github.com:CachyOS/linux-cachyos.git
git clone git@github.com:CachyOS/kernel-patches.git
git clone git@github.com:sirlucjan/kernel-patches.git lucjan

echo  "Clone aur stuff"
mkdir -p ${AUR}/kernel
cd ${AUR}/kernel
git clone ssh://aur@aur.archlinux.org/linux-cachyos.git
git clone ssh://aur@aur.archlinux.org/linux-cachyos-tt.git
git clone ssh://aur@aur.archlinux.org/linux-cachyos-cfs.git
git clone ssh://aur@aur.archlinux.org/linux-cachyos-bore.git
git clone ssh://aur@aur.archlinux.org/linux-cachyos-bmq.git
git clone ssh://aur@aur.archlinux.org/linux-cachyos-pds.git
git clone ssh://aur@aur.archlinux.org/linux-cachyos-cacule.git
git clone ssh://aur@aur.archlinux.org/linux-cachyos-hardened.git
git clone ssh://aur@aur.archlinux.org/linux-cacule.git
git clone ssh://aur@aur.archlinux.org/linux-cacule-rdb.git
git clone ssh://aur@aur.archlinux.org/linux-tt.git
cd ${AUR}
git clone ssh://aur@aur.archlinux.org/lapce-git.git
git clone ssh://aur@aur.archlinux.org/mold-git.git
git clone ssh://aur@aur.archlinux.org/makepkg-optimize-mold.git
git clone ssh://aur@aur.archlinux.org/gcc-git.git
git clone ssh://aur@aur.archlinux.org/contour.git
git clone ssh://aur@aur.archlinux.org/ananicy-rules.git

echo  "Apply resolution"
xlayoutdisplay -p DP-2 -o DP-2 -o DP-4

