# Personal Configuration (dotfiles) - Arch Linux + Hyprland

This repository contains my personal system configurations (dotfiles), including application settings, custom scripts, visual themes, cursor sets, custom fonts, and wallpapers. It is designed to be cloned onto a fresh Arch Linux installation and run as a single script to completely reconstruct my working environment and user experience.

## Project Structure

The repository is organized as follows:
- **`backup.sh`**: A script to gather and update configurations from your local system into this repository.
- **`install.sh`**: The main restoration script that installs all packages and symlinks configurations on the new system.
- **`packages/`**: Lists of explicitly installed packages (native packages via `pacman` and AUR packages via `yay`/`paru`).
- **`dot_config/`**: Copies of application configurations (mapping to `~/.config/`). Includes settings for Hyprland, Waybar, Alacritty, Kitty, Cava, Wofi, Lazygit, Yazi, Swaync, Wlogout, etc.
- **`home/`**: Files mapping to the user's home directory (`~/`), such as `.zshrc`, `.gitconfig`, and `.gtkrc-2.0`.
- **`bin/`** and **`local_bin/`**: Custom user scripts (mapping to `~/bin/` and `~/.local/bin/`). Heavy compiled binaries (e.g. `terraform`, `uv`) are automatically excluded to keep the repository lightweight.
- **`scripts/`**: Additional automation scripts (mapping to `~/scripts/`).
- **`wallpapers/`**: Custom wallpaper files and local assets. The massive `mylinuxforwork` wallpaper repository is cloned dynamically during installation to save Git storage space.
- **`themes/`** and **`icons/`**: Custom visual styles and icon packages, including the `Graphite-Dark` theme suite.

---

## How to Use the Backup System

### 1. On Your Current Computer (Saving Changes)
Whenever you make updates to your configurations, write new scripts, or install new packages that you want to back up:

```bash
./backup.sh
```

The script will update the package lists and copy modified configurations to the repository. You can then commit and push these changes to GitHub:

```bash
git add .
git commit -m "update: sync latest configurations and scripts"
git push origin main
```

---

### 2. On Your New Computer (Restoring Everything)
Once you have installed Arch Linux on your new machine, open a terminal and run the following commands:

1. **Clone this repository**:
   ```bash
   git clone https://github.com/hernanrengel/personal-config.git ~/personal-config
   ```

2. **Navigate to the directory**:
   ```bash
   cd ~/personal-config
   ```

3. **Run the installation script**:
   ```bash
   ./install.sh
   ```

### What does the installation script do automatically?
1. **OS Check**: Verifies that the host system is running Arch Linux.
2. **AUR Helper Bootstrap**: Installs development utilities and compiles `yay` automatically if no AUR helper is detected.
3. **Package Installation**: Installs all native pacman and AUR packages from your stored list silently and efficiently.
4. **Safety Backups**: Detects pre-existing files/folders in `~/.config/` or `~/` and renames them with a `.backup` suffix so you do not lose any existing local data.
5. **Symlink Deployment**: Creates symbolic links from your cloned repository to your system directories (e.g., `~/.config/hypr` points to the repository folder).
   > [!NOTE]
   > By using symbolic links, any future configuration tweaks you make (such as editing `hyprland.conf` or updating your `.zshrc`) will write directly to the files in the local Git repository. This lets you simply run `git commit` and `git push` to keep your backups updated without copying files.
6. **Shell Setup**: Installs Oh My Zsh and clones custom plugins (`zsh-autosuggestions` and `zsh-syntax-highlighting`).
7. **Wallpaper Restoration**: Performs a fast, shallow clone (`--depth 1`) of the `mylinuxforwork/wallpaper` pack and links your personal wallpapers.
8. **Default Shell Activation**: Automatically changes the default system shell to Zsh for your user account.
