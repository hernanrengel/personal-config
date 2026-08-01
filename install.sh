#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Terminal colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Starting personal-config Restoration ===${NC}"

# Get repo root directory
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# 1. OS check (designed for Arch Linux)
if [ ! -f /etc/arch-release ]; then
    echo -e "${RED}Error: This script is designed for Arch Linux.${NC}"
    echo -e "If you are using another distribution, please install packages manually and run configuration linking."
    exit 1
fi

# Ask for sudo credentials early
echo -e "${YELLOW}Please enter your password for administrative privileges:${NC}"
sudo -v

# Keep-alive: update existing sudo time stamp until script has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; 2>/dev/null; } &

# 2. Check and install yay (AUR Helper)
if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
    echo -e "${YELLOW}AUR helper (yay/paru) not found. Installing yay...${NC}"
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    (cd /tmp/yay-bin && makepkg -si --noconfirm)
    rm -rf /tmp/yay-bin
    echo -e "${GREEN}yay installed successfully!${NC}"
fi

AUR_HELPER="yay"
if command -v paru &>/dev/null; then
    AUR_HELPER="paru"
fi

# 3. Install native pacman packages
if [ -f packages/pacman-packages.txt ]; then
    echo -e "${YELLOW}Installing native pacman packages...${NC}"
    # Filter out empty lines or comments, and install
    sudo pacman -S --needed --noconfirm - < packages/pacman-packages.txt || {
        echo -e "${RED}Warning: Some native packages failed to install. Installing one by one...${NC}"
        while read -r pkg; do
            [ -z "$pkg" ] && continue
            sudo pacman -S --needed --noconfirm "$pkg" || echo -e "  -> ${RED}Failed to install native package: $pkg${NC}"
        done < packages/pacman-packages.txt
    }
fi

# 4. Install AUR packages
if [ -f packages/aur-packages.txt ]; then
    echo -e "${YELLOW}Installing AUR packages...${NC}"
    $AUR_HELPER -S --needed --noconfirm - < packages/aur-packages.txt || {
        echo -e "${RED}Warning: Some AUR packages failed to install. Installing one by one...${NC}"
        while read -r pkg; do
            [ -z "$pkg" ] && continue
            $AUR_HELPER -S --needed --noconfirm "$pkg" || echo -e "  -> ${RED}Failed to install AUR package: $pkg${NC}"
        done < packages/aur-packages.txt
    }
fi

# Helper function to create safe symlinks (with backups)
symlink_item() {
    local src="$1"
    local dest="$2"
    
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        # If it's already symlinked to the correct path, skip
        if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
            return 0
        fi
        echo -e "  -> Backing up existing ${YELLOW}$(basename "$dest")${NC} to ${dest}.backup"
        rm -rf "${dest}.backup"
        mv "$dest" "${dest}.backup"
    fi
    
    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
    echo -e "  -> Linked ${GREEN}$dest${NC} -> $src"
}

# 5. Restore .config directories
echo -e "${YELLOW}Symlinking application configurations...${NC}"
if [ -d dot_config ]; then
    for item in dot_config/*; do
        if [ -e "$item" ]; then
            name="$(basename "$item")"
            symlink_item "$item" "$HOME/.config/$name"
        fi
    done
fi

# 6. Restore Home Dotfiles
echo -e "${YELLOW}Symlinking home dotfiles...${NC}"
if [ -d home ]; then
    for item in home/* home/.*; do
        # Avoid looping . and ..
        [ "$(basename "$item")" = "." ] && continue
        [ "$(basename "$item")" = ".." ] && continue
        if [ -f "$item" ]; then
            name="$(basename "$item")"
            symlink_item "$item" "$HOME/$name"
        fi
    done
fi

# 7. Restore Scripts & Bin
echo -e "${YELLOW}Symlinking scripts and bin folders...${NC}"
if [ -d scripts ]; then
    symlink_item "$REPO_DIR/scripts" "$HOME/scripts"
fi
if [ -d bin ]; then
    symlink_item "$REPO_DIR/bin" "$HOME/bin"
fi

# Restore ~/.local/bin/ scripts individually
if [ -d local_bin ]; then
    echo -e "${YELLOW}Symlinking custom scripts to ~/.local/bin/...${NC}"
    mkdir -p "$HOME/.local/bin"
    for file in local_bin/*; do
        if [ -f "$file" ]; then
            name="$(basename "$file")"
            symlink_item "$file" "$HOME/.local/bin/$name"
        fi
    done
fi

# 8. Restore themes and icons
echo -e "${YELLOW}Symlinking themes and icons...${NC}"
if [ -d themes ]; then
    mkdir -p "$HOME/.themes"
    for theme in themes/*; do
        if [ -d "$theme" ]; then
            name="$(basename "$theme")"
            symlink_item "$theme" "$HOME/.themes/$name"
        fi
    done
fi
if [ -d icons ]; then
    mkdir -p "$HOME/.icons"
    for icon in icons/*; do
        if [ -d "$icon" ]; then
            name="$(basename "$icon")"
            symlink_item "$icon" "$HOME/.icons/$name"
        fi
    done
fi

# 9. Restore wallpapers and clone wallpaper pack
echo -e "${YELLOW}Restoring wallpapers...${NC}"
mkdir -p "$HOME/Pictures/Wallpapers/curated"

# Link custom wallpapers from repo
if [ -d wallpapers ]; then
    for wp in wallpapers/*; do
        name="$(basename "$wp")"
        if [ "$name" != "curated" ] && [ -f "$wp" ]; then
            symlink_item "$wp" "$HOME/Pictures/Wallpapers/$name"
        fi
    done
    # If custom subdirectories are present, link them too
    for wp_dir in wallpapers/*; do
        name="$(basename "$wp_dir")"
        if [ "$name" != "curated" ] && [ -d "$wp_dir" ]; then
            symlink_item "$wp_dir" "$HOME/Pictures/Wallpapers/$name"
        fi
    done
fi

# Clone the mylinuxforwork/wallpaper pack (optimizing size with --depth 1)
if [ ! -d "$HOME/Pictures/Wallpapers/wallpaper" ]; then
    echo -e "${YELLOW}Cloning wallpaper repository (depth=1 for speed)...${NC}"
    git clone --depth 1 https://github.com/mylinuxforwork/wallpaper.git "$HOME/Pictures/Wallpapers/wallpaper"
    echo -e "${GREEN}Wallpaper repository cloned!${NC}"
else
    echo -e "  -> Wallpaper repository already exists, skipping clone"
fi

# 10. Bootstrap Shell (Oh My Zsh & custom plugins)
echo -e "${YELLOW}Setting up ZSH and Oh My Zsh...${NC}"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "  -> Oh My Zsh not found. Installing..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install custom plugins if not present
ZSH_CUSTOM_PLUGINS="$HOME/.oh-my-zsh/custom/plugins"
mkdir -p "$ZSH_CUSTOM_PLUGINS"

if [ ! -d "$ZSH_CUSTOM_PLUGINS/zsh-autosuggestions" ]; then
    echo -e "  -> Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_PLUGINS/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM_PLUGINS/zsh-syntax-highlighting" ]; then
    echo -e "  -> Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM_PLUGINS/zsh-syntax-highlighting"
fi

# Change shell to Zsh
CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
ZSH_PATH="$(which zsh)"
if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
    echo -e "${YELLOW}Changing default shell to Zsh...${NC}"
    sudo chsh -s "$ZSH_PATH" "$USER"
fi

echo -e "\n${GREEN}=== Restore Complete! ===${NC}"
echo -e "Please log out and log back in (or reboot) for all changes, the shell, and Hyprland variables to take effect."
