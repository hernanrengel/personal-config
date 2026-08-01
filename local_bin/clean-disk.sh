#!/usr/bin/env bash
set -euo pipefail

before=$(df / | awk 'NR==2 {print $3}')

echo "Limpiando cachés..."

# AUR helpers
rm -rf ~/.cache/yay ~/.cache/paru

# Build caches
rm -rf ~/.cache/go-build ~/.cache/node-gyp

# Pacman/yay paquetes no instalados (no pregunta)
yay -Sc --noconfirm 2>/dev/null || true
sudo pacman -Sc --noconfirm 2>/dev/null || true

after=$(df / | awk 'NR==2 {print $3}')
freed=$(( (before - after) / 1024 ))

echo "Listo. Liberados: ${freed} MB"
df -h /
