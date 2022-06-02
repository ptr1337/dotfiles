#!/bin/bash

paru -S --noconfirm llvm clang lld llvm-libs compiler-rt mesa ungoogled-chromium cachyos discord-canary flameshot krusader-git cachyos-gaming-meta bitwarden keepassxc latte-dock mold-git 64gram-desktop-bin cpu-x-git flameshot bleachbit eddie-ui-git makepkg-optimize-mold github-desktop-bin atom bleachbit meld smartgit thunderbird zsh xlayoutdisplay chromium-extension-web-store beautysh autopep8 shellcheck xclip vscodium-bin micro zenmonitor3-git zsh aria2-fast element-desktop buildcache-git

mkdir projects
mkdir projects/cachyos
mkdir projects/kernel
mkdir repo
cd repo
git clone https://github.com/ptr1337/arch-packages.git
git clone https://github.com/Frogging-Family/nvidia-all
git clone git@github.com:CachyOS/linux-cachyos.git
cd ..
cd projects/cachyos
git clone git@github.com:CachyOS/calamares-config.git
git@github.com:CachyOS/CachyOS-Live-ISO.git
git@github.com:CachyOS/CachyOS-PKGBUILDS.git
git@github.com:CachyOS/CachyOS-Browser-Common.git
git@github.com:CachyOS/CachyOS-Settings.git
cd ..
cd kernel
git clone git@github.com:CachyOS/linux.git
git clone git@github.com:CachyOS/linux-cachyos.git
git clone git@github.com:ptr1337/kernel-patches.git
git clone git@github.com:ptr1337/linux-cacule.git

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
