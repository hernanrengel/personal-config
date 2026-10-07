# CLAUDE.md - AI Assistant Guidelines

This file provides system instructions, build/run commands, and development guidelines for AI assistants (like Claude Code, Antigravity, or Cursor) working in this repository.

## Commands

### System Backup & Sync
* **Backup all configs:** `./backup.sh`
* **Restore/Deploy configs:** `./install.sh`
* **System Update:** `~/scripts/update-system.sh` (or shell alias `update`)

### Git Workflow
* **Stage and commit changes:**
  ```bash
  git add .
  git commit -m "commit message"
  git push origin main
  ```

---

## Directory Structure & Roles

* **`dot_config/`**: Holds configurations destined for `~/.config/`.
  * **Hyprland:** `dot_config/hypr/hyprland.conf` (All system shortcuts/keybindings are defined here starting around line 185).
  * **Waybar:** `dot_config/waybar/config.jsonc` (modules) and `style.css` (styles).
  * **IDE Settings:** `dot_config/Code - OSS/User/` & `dot_config/Cursor/User/` (Contains **only** `settings.json`, `keybindings.json`, and `snippets/` to avoid committing massive workspace cache).
  * **Touchpad Gestures:** `dot_config/fusuma/config.yml`.
* **`home/`**: Holds configuration dotfiles for the home directory `~/` (e.g. `.zshrc`, `.gitconfig`, `.fvmrc`).
  * **SDKMAN:** Config is stored selectively at `home/sdkman/config` (restored to `~/.sdkman/etc/config`).
* **`local_bin/`**: Custom user scripts deployed to `~/.local/bin/`. Heavy/compiled binaries (e.g. `terraform`, `uv`) are excluded.
* **`packages/`**: Tracked native packages (`pacman-packages.txt`) and AUR packages (`aur-packages.txt`).

---

## Guidelines for AI Assistants

### 0. Communication & Behavior (CRITICAL)
* **Keep it simple and direct:** Focus strictly on the user's specific request. Do not write long theoretical explanations, do not go in loops, and **never** suggest or run Git commands (commit/push) unless explicitly asked.
* **Validate first:** Before making assumptions about desktop configuration rules, run verification commands (like `hyprctl configerrors` and checking the package version) to ensure syntax compatibility.

### 1. Modifying Configurations & Scripts
* **Modularity:** Keep custom user scripts in `local_bin/` or `scripts/`. Avoid creating ad-hoc wrappers inside home configuration files.
* **Backup Safety:** When adding new configuration folders to `~/.config/`, ensure they are added to `CONFIG_DIRS` in `backup.sh` and not skipped.
* **Cache Avoidance:** Never backup entire directories of IDEs, web browsers, or language managers (like `.nvm/`, `.sdkman/`, `.fvm/`, `.config/Code`). Only backup settings files (`.json`, `.yml`, `.conf`).
* **Links:** Always check if a new configuration requires special handling in `install.sh` (e.g. individual symlinking of config files rather than folder linking to avoid cache leakage).

### 2. Code Style
* **Shell Scripts:** Use Bash/POSIX shell standards. Include terminal colors (`GREEN`, `BLUE`, `YELLOW`, `RED`) for feedback. Use `set -euo pipefail` for robustness.
* **Keybindings:** Document any new shortcuts inside the `### KEYBINDINGS ###` section of `dot_config/hypr/hyprland.conf` so the user can easily review them.

### 3. Wine / Lutris / Game Window Rules
* **Game Window Matching:** Always match game executables case-insensitively using character classes (e.g. `^([jJ][uU][vV][iI][oO](\.[eE][xX][eE])?|[hH][oO][nN](\.[eE][xX][eE])?|[wW][oO][wW]([cC]lassic)?|[dD][iI][aA][bB][lL][oO]|[oO][vV][eE][rR][wW][aA][tT][cC][hH]|[hH][eE][aA][rR][tT][hH][sS][tT][oO][nN][eE])(\.[eE][xX][eE])?$`) to avoid missing different capitalization/runtime class names of Wine/XWayland windows.
* **Game Fullscreen Fixes:** Use the new flat match syntax (`windowrule = match:class <regex>, <effect> <val>`) with `fullscreen 1` and `border_size 0` to ensure games bypass the window manager's borders, Waybar/AGS, and lock the cursor. For example:
  ```ini
  windowrule = match:class ^(mygame)$, float 1
  windowrule = match:class ^(mygame)$, size 2560 1080
  windowrule = match:class ^(mygame)$, move 0 0
  windowrule = match:class ^(mygame)$, fullscreen 1
  windowrule = match:class ^(mygame)$, border_size 0
  ```


