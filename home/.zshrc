# ========================
# Zsh Configuration for Arch
# ========================

# Path to Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set theme to agnoster (requires Nerd Fonts)
ZSH_THEME="agnoster"

# Enable plugins
plugins=(
  git
  # autojump
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# ========================
# Starship Prompt
# ========================
# Install starship: sudo pacman -S starship
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# ========================
# Aliases
# ========================
# eza (mejor ls)
if command -v eza &>/dev/null; then
    alias ls='eza --icons'
    alias ll='eza -lh --icons --git'
    alias la='eza -lha --icons --git'
    alias lt='eza --tree --icons --level=2'
else
    alias ll='ls -lh --color=auto'
    alias la='ls -lha --color=auto'
fi

# bat (mejor cat)
if command -v bat &>/dev/null; then
    alias cat='bat --style=plain'
    alias catp='bat'
fi

# lazygit
alias lg='lazygit'

# git shortcuts
alias gs='git status'
alias gp='git pull'
alias gd='git diff'

# navegación
alias ..='cd ..'
alias ...='cd ../..'

# sistema
alias update='sudo bash ~/.local/bin/../scripts/update-system.sh 2>/dev/null || sudo bash ~/scripts/update-system.sh'

# SSH con soporte completo para kitty (colores, copy/paste, terminfo)
alias kssh='kitty +kitten ssh'

# dust - uso de disco
alias du='dust'
alias duh='dust -H'

# yazi - abre file manager y al salir cambia al directorio donde quedaste
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# ========================
# Autojump Initialization
# ========================
# [[ -s /usr/share/autojump/autojump.sh ]] && source /usr/share/autojump/autojump.sh

# ========================
# Zsh Options
# ========================
# Correct minor typos in commands
setopt CORRECT

# Share history across sessions
setopt SHARE_HISTORY

# Case-insensitive globbing
setopt NO_CASE_GLOB

# ========================
# Prompt Customization (fallback if Starship not installed)
# ========================
# Uncomment if you want a fallback prompt without Starship
# PROMPT='%n@%m %1~ %# '

# (autosuggestions and syntax-highlighting are loaded automatically via Oh My Zsh plugins list)

# ========================
# Load changes
# ========================
export LANG=en_US.UTF-8

fastfetch

# Android SDK
export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_SDK_ROOT=$HOME/Android/Sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH
export CHROME_EXECUTABLE=/usr/bin/google-chrome-stable

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# zoxide (mejor z - directorio inteligente)
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh --cmd z)"
fi


# export JAVA_HOME=/opt/android-studio/jbr
# export PATH=$JAVA_HOME/bin:$PATH

export PATH="$HOME/.local/share/gem/ruby/3.4.0/bin:$PATH"


export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


alias flutter-lite="~/flutter-lite.sh"


# bun completions
[ -s "/home/brosso3d/.bun/_bun" ] && source "/home/brosso3d/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export PATH="$HOME/fvm/default/bin:$HOME/.pub-cache/bin:$PATH"

# --- SDKMAN ---
#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

# Java from SDKMAN
export JAVA_HOME="$HOME/.sdkman/candidates/java/current"
export PATH="$JAVA_HOME/bin:$PATH"

# Jetbrains
export DATAGRIP_JDK=/usr/lib/jvm/jre-jetbrains

export PATH="$HOME/.local/bin:$PATH"
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

alias nvidia-run='__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia'

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Heroes of Newerth (Juvio launcher via Wine)
# Render en NVIDIA (PRIME offload) + EGL NVIDIA. La resolucion (2560x1080) la fija startup.cfg (vid_resolution).
# K2 reescribe el cfg al salir y a veces lo deja en 119,34 (ventana diminuta); la funcion sana
# vid_resolution/width/height ANTES de lanzar. Recuperacion en vivo: SUPER+SHIFT+H (Hyprland).
hon() {
  local cfg="$HOME/Documents/Juvio/Heroes of Newerth/startup.cfg"
  if [ -f "$cfg" ]; then
    local tmp; tmp=$(mktemp)
    iconv -f UTF-16 -t UTF-8 "$cfg" \
      | sed -E 's/(SetSave "vid_resolution") "[^"]*"/\1 "2560,1080,0"/;
                s/(SetSave "vid_width") "[^"]*"/\1 "2560"/;
                s/(SetSave "vid_height") "[^"]*"/\1 "1080"/' > "$tmp"
    { printf '\xff\xfe'; iconv -f UTF-8 -t UTF-16LE "$tmp"; } > "$cfg"
    rm -f "$tmp"
  fi
  __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia \
  __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json \
  __VK_LAYER_NV_optimus=NVIDIA_only WINEPREFIX="$HOME/Games/juvio" WINEDEBUG=-all \
  wine "$HOME/Games/juvio/drive_c/Games/Juvio/bin/juvio.exe" >/tmp/juvio.log 2>&1 &
}
