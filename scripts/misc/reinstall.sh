#!/bin/bash

wget https://build.cachyos.org/cachyos-repo.tar.xz
tar xvf cachyos-repo.tar.xz
chmod +x cachyos-repo.sh
sudo ./cachyos-repo.sh
wget https://raw.githubusercontent.com/ptr1337/dotfiles/master/scripts/misc/makepkg.conf
sudo mv makepkg.conf /etc/makepkg.conf
wget https://raw.githubusercontent.com/ptr1337/dotfiles/master/config/modprobed.db
mv modprobed.db


paru -S --noconfirm nextcloud-client llvm clang lld llvm-libs compiler-rt mesa ungoogled-chromium cachyos discord-canary flameshot krusader-git cachyos-gaming-meta bitwarden keepassxc latte-dock mold-git 64gram-desktop session-desktop-bin cpu-x-git flameshot bleachbit eddie-ui-git hummingbird-bin makepkg-optimize-mold github-desktop-bin atom bleachbit meld smartgit thunderbird zsh xlayoutdisplay chromium-extension-web-store beautysh autopep8 shellcheck xclip vscodium-bin micro zenmonitor3-git zsh aria2-fast element-desktop

mkdir projects
mkdir projects/cachyos
mkdir projects/kernel
mkdir repo
git clone https://github.com/ptr1337/dotfiles.git .dotfiles
cd repo
git clone https://github.com/ptr1337/arch-packages.git
git clone https://github.com/Frogging-Family/nvidia-all

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
