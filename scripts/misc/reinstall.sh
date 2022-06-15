#!/bin/bash

AUR=/home/ptr1337/projects/kernel/aur

paru -S llvm clang lld llvm-libs compiler-rt mesa cachyos discord-canary flameshot krusader-git cachyos-gaming-meta bitwarden cpu-x-git flameshot bleachbit eddie-ui-git makepkg-optimize-mold atom bleachbit meld smartgit thunderbird zsh xlayoutdisplay beautysh autopep8 shellcheck xclip vscodium-bin micro zenmonitor3-git zsh aria2-fast aur/kotatogram-desktop kitty


mkdir projects
mkdir projects/cachyos
mkdir projects/kernel
mkdir repo
cd repo
git clone https://github.com/Frogging-Family/nvidia-all
git clone git@github.com:CachyOS/linux-cachyos.git
cd ..
cd projects/cachyos
git clone git@github.com:CachyOS/calamares-config.git
git clone git@github.com:CachyOS/CachyOS-Live-ISO.git
git clone git@github.com:CachyOS/CachyOS-PKGBUILDS.git
git clone git@github.com:CachyOS/CachyOS-Browser-Common.git
git clone git@github.com:CachyOS/CachyOS-Settings.git
git clone https://github.com/ptr1337/llvm-bolt-scripts.git
cd ..
cd kernel
git clone git@github.com:CachyOS/linux.git
git clone git@github.com:CachyOS/linux-cachyos.git
git clone git@github.com:ptr1337/kernel-patches.git
git clone git@github.com:ptr1337/linux-cacule.git
git clone git@github.com:ptr1337/toolchain.git
git clone git@github.com:ptr1337/makepkg-optimize.git

mkdir -p ${AUR}
cd ${AUR}
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
git clone ssh://aur@aur.archlinux.org/linux-bore.git
git clone ssh://aur@aur.archlinux.org/linux-tt.git


xlayoutdisplay -p DP-2 -o DP-2 -o DP-4

# kwinrc
#[Compositing]
#GLCore=true
#MaxFPS=244
#OpenGLIsUnsafe=false
#RefreshRate=244
#SetMaxFramesAllowed=true
#VSyncMechanism=OML


#nvidia
#     Option         "Coolbits" "24"
