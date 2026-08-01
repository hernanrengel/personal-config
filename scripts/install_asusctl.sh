#!/usr/bin/env bash
set -e

echo "==> Agregando GPG key del repo g14..."
KEY="8F654886F17D497FEFE3DB448B15A6B0E9A3FA35"
if ! sudo pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys "$KEY" 2>/dev/null; then
    echo "    Keyserver falló, descargando llave directamente..."
    sudo curl -o /tmp/g14.gpg https://arch.asus-linux.org/g14.gpg
    sudo pacman-key --add /tmp/g14.gpg
    rm -f /tmp/g14.gpg
fi
sudo pacman-key --lsign-key "$KEY"

echo "==> Agregando repo [g14] a pacman.conf..."
if ! grep -q '\[g14\]' /etc/pacman.conf; then
    echo -e '\n[g14]\nServer = https://arch.asus-linux.org' | sudo tee -a /etc/pacman.conf
else
    echo "    [g14] ya existe, saltando..."
fi

echo "==> Actualizando base de datos de paquetes..."
sudo pacman -Suy --noconfirm

echo "==> Removiendo TLP (conflicta con asusctl)..."
if pacman -Q tlp &>/dev/null; then
    sudo systemctl disable --now tlp.service 2>/dev/null || true
    sudo pacman -Rns --noconfirm tlp
else
    echo "    TLP no instalado, saltando..."
fi

echo "==> Instalando asusctl y power-profiles-daemon..."
sudo pacman -S --noconfirm asusctl power-profiles-daemon

echo "==> Habilitando servicios principales..."
sudo systemctl enable --now asusd
sudo systemctl enable --now power-profiles-daemon

echo "==> Habilitando servicios NVIDIA para suspend/hibernate..."
sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

echo ""
echo "Instalacion completada."
echo "  asusctl --help       -> ver comandos disponibles"
echo "  asusctl profile -l   -> listar perfiles de potencia"
echo "  asusctl profile -p   -> ver perfil activo"
