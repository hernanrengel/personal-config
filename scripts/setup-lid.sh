#!/bin/bash
set -euo pipefail

echo "==> Configurando comportamiento de tapa del laptop..."

# 1. logind: suspender al cerrar, ignorar si hay monitor externo
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/lid.conf > /dev/null << 'EOF'
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
echo "    logind configurado."

# 2. Hook de resume: enciende el display de Hyprland al despertar
sudo tee /usr/lib/systemd/system-sleep/hypr-dpms.sh > /dev/null << 'EOF'
#!/bin/bash
if [ "$1" = "post" ]; then
    sleep 1
    INSTANCE=$(ls /tmp/hypr/ 2>/dev/null | head -1)
    [ -n "$INSTANCE" ] && HYPRLAND_INSTANCE_SIGNATURE="$INSTANCE" hyprctl dispatch dpms on 2>/dev/null || true
fi
EOF
sudo chmod +x /usr/lib/systemd/system-sleep/hypr-dpms.sh
echo "    Hook de resume instalado."

# 3. Aplicar cambios de logind sin reiniciar
sudo systemctl restart systemd-logind
echo "    systemd-logind reiniciado."

echo ""
echo "Listo. Al cerrar la tapa: suspende. Al abrir: enciende el display."
echo "Con monitor externo conectado: la tapa no hace nada."
