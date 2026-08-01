#!/usr/bin/env bash
set -e

echo "==> Creando wrapper /usr/local/bin/kbd-backlight-set..."
sudo tee /usr/local/bin/kbd-backlight-set > /dev/null << 'EOF'
#!/bin/bash
echo "$1" > /sys/class/leds/asus::kbd_backlight/brightness
EOF
sudo chmod +x /usr/local/bin/kbd-backlight-set

echo "==> Agregando regla sudoers..."
echo "brosso3d ALL=(ALL) NOPASSWD: /usr/local/bin/kbd-backlight-set" | sudo tee /etc/sudoers.d/kbd-backlight > /dev/null

echo "==> Verificando..."
sudo /usr/local/bin/kbd-backlight-set 1 && echo "Backlight encendido (low)" || echo "ERROR al escribir"

echo "Listo. Recarga waybar: pkill waybar; waybar &"
