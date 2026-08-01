#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Terminal colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Starting personal-config Backup ===${NC}"

# Get repo root directory
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# 1. Create directory structure
echo -e "${YELLOW}[1/8] Creating repository directories...${NC}"
mkdir -p dot_config packages home bin scripts local_bin wallpapers themes icons

# 2. Backup package lists
echo -e "${YELLOW}[2/8] Exporting installed package lists...${NC}"
if command -v pacman &>/dev/null; then
    pacman -Qeq > packages/pacman-packages.txt
    echo -e "  -> Exported native pacman packages (${GREEN}$(wc -l < packages/pacman-packages.txt)${NC} packages)"
else
    echo -e "  -> ${RED}Warning: pacman not found, skipping native package list${NC}"
fi

if command -v yay &>/dev/null; then
    yay -Qemq > packages/aur-packages.txt
    echo -e "  -> Exported AUR packages (${GREEN}$(wc -l < packages/aur-packages.txt)${NC} packages)"
elif command -v paru &>/dev/null; then
    paru -Qemq > packages/aur-packages.txt
    echo -e "  -> Exported AUR packages (${GREEN}$(wc -l < packages/aur-packages.txt)${NC} packages)"
else
    # Fallback to general list of foreign packages
    if command -v pacman &>/dev/null; then
        pacman -Qemq > packages/aur-packages.txt
        echo -e "  -> Exported foreign packages (${GREEN}$(wc -l < packages/aur-packages.txt)${NC} packages)"
    fi
fi

# 3. Backup config files (~/.config)
echo -e "${YELLOW}[3/8] Backing up ~/.config folders...${NC}"
CONFIG_DIRS=(
    "alacritty"
    "cava"
    "fastfetch"
    "hypr"
    "kitty"
    "lazygit"
    "swaync"
    "waybar"
    "wlogout"
    "wofi"
    "yazi"
    "gtk-3.0"
    "gtk-4.0"
    "nwg-look"
)

for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$HOME/.config/$dir" ]; then
        echo -e "  -> Backing up ~/.config/$dir"
        rm -rf "dot_config/$dir"
        cp -r "$HOME/.config/$dir" "dot_config/"
    else
        echo -e "  -> ${YELLOW}Skipped ~/.config/$dir (Not found)${NC}"
    fi
done

if [ -f "$HOME/.config/starship.toml" ]; then
    echo -e "  -> Backing up ~/.config/starship.toml"
    cp "$HOME/.config/starship.toml" dot_config/
fi

# 4. Backup Home Dotfiles
echo -e "${YELLOW}[4/8] Backing up home dotfiles...${NC}"
HOME_FILES=(
    ".zshrc"
    ".gitconfig"
    ".gitconfig-bluetrail"
    ".gtkrc-2.0"
)

for file in "${HOME_FILES[@]}"; do
    if [ -f "$HOME/$file" ]; then
        echo -e "  -> Backing up ~/$file"
        cp "$HOME/$file" home/
    else
        echo -e "  -> ${YELLOW}Skipped ~/$file (Not found)${NC}"
    fi
done

# 5. Backup custom scripts from ~/scripts (excluding node_modules)
echo -e "${YELLOW}[5/8] Backing up ~/scripts (excluding node_modules)...${NC}"
if [ -d "$HOME/scripts" ]; then
    # Clear existing and copy recursively except node_modules
    rm -rf scripts/*
    for item in "$HOME/scripts"/*; do
        if [ -e "$item" ]; then
            name="$(basename "$item")"
            if [ "$name" != "node_modules" ]; then
                cp -r "$item" scripts/
            fi
        fi
    done
    echo -e "  -> Backed up ~/scripts"
else
    echo -e "  -> ${YELLOW}Skipped ~/scripts (Not found)${NC}"
fi

# 6. Backup ~/bin and ~/.local/bin scripts
echo -e "${YELLOW}[6/8] Backing up custom scripts from bin directories...${NC}"
if [ -d "$HOME/bin" ]; then
    rm -rf bin/*
    cp -r "$HOME/bin"/* bin/
    echo -e "  -> Backed up ~/bin"
fi

if [ -d "$HOME/.local/bin" ]; then
    rm -rf local_bin/*
    # Copy only script files, exclude compiled ELF binaries (like terraform, uv, session-manager-plugin)
    for f in "$HOME/.local/bin"/*; do
        if [ -f "$f" ] && [ ! -L "$f" ]; then
            if ! file "$f" | grep -q "ELF"; then
                cp "$f" local_bin/
            fi
        fi
    done
    echo -e "  -> Backed up custom scripts from ~/.local/bin (excluded compiled binaries)"
else
    echo -e "  -> ${YELLOW}Skipped ~/.local/bin (Not found)${NC}"
fi

# 7. Backup themes and icons
echo -e "${YELLOW}[7/8] Backing up themes and icons...${NC}"
if [ -d "$HOME/.themes" ]; then
    rm -rf themes/*
    cp -r "$HOME/.themes"/* themes/
    echo -e "  -> Backed up ~/.themes"
fi
if [ -d "$HOME/.icons" ]; then
    rm -rf icons/*
    cp -r "$HOME/.icons"/* icons/
    echo -e "  -> Backed up ~/.icons"
fi

# 8. Backup Wallpapers (excluding the wallpaper/ repo directory)
echo -e "${YELLOW}[8/8] Backing up wallpapers...${NC}"
if [ -d "$HOME/Pictures/Wallpapers" ]; then
    rm -rf wallpapers/*
    # Create curated dir just in case
    mkdir -p wallpapers/curated
    for item in "$HOME/Pictures/Wallpapers"/*; do
        if [ -e "$item" ]; then
            name="$(basename "$item")"
            # Exclude mylinuxforwork/wallpaper repo since install.sh will clone it
            if [ "$name" != "wallpaper" ] && [ "$name" != "curated" ]; then
                cp -r "$item" wallpapers/
            fi
        fi
    done
    echo -e "  -> Backed up custom wallpapers (excluded large wallpaper repo)"
else
    echo -e "  -> ${YELLOW}Skipped wallpapers folder (Not found)${NC}"
fi

echo -e "\n${GREEN}=== Backup Complete! ===${NC}"
echo -e "You can now run 'git add .', commit, and push your configurations."
