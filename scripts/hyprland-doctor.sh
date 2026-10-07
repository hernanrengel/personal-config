#!/bin/bash
# hyprland-doctor.sh — Comprueba la salud del entorno Hyprland, variables y demonios.
set -euo pipefail

# Colores ANSI
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
BLUE='\e[34m'
NC='\e[0m' # Sin Color

# Funciones de impresión
ok() {
    echo -e "${GREEN}[ OK ]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[ ADVERTENCIA ]${NC} $1"
}

err() {
    echo -e "${RED}[ ERROR ]${NC} $1"
}

info() {
    echo -e "${BLUE}==>${NC} $1"
}

echo -e "\n=== 🏥 DIAGNÓSTICO DE SALUD DE HYPRLAND ==="
echo -e "Fecha: $(date)\n"

# 1. Comprobación de Sesión Activa
info "Comprobando estado de la sesión..."
if [[ "${XDG_CURRENT_DESKTOP:-}" != "Hyprland" ]]; then
    warn "No estás corriendo en una sesión de Hyprland (XDG_CURRENT_DESKTOP='${XDG_CURRENT_DESKTOP:-}')"
else
    ok "Sesión activa detectada: Hyprland"
fi

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    ok "Instancia de Hyprland firma: $HYPRLAND_INSTANCE_SIGNATURE"
    SOCKET_PATH="/run/user/$(id -u)/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    if [[ -S "$SOCKET_PATH" ]]; then
        ok "Socket de eventos de Hyprland activo: $SOCKET_PATH"
    else
        err "Socket de eventos (.socket2.sock) NO existe o no es un socket en $SOCKET_PATH"
    fi
else
    err "HYPRLAND_INSTANCE_SIGNATURE no está definida. ¿Estás en un entorno gráfico Hyprland?"
fi

# 2. Comprobación de Dependencias Críticas
echo ""
info "Verificando ejecutables y herramientas esenciales..."
DEPS=(
    "hyprland"
    "hyprctl"
    "ags"
    "awww"
    "socat"
    "brightnessctl"
    "pactl"
    "notify-send"
)

for dep in "${DEPS[@]}"; do
    if command -v "$dep" &>/dev/null; then
        path_dep=$(which "$dep")
        if [[ "$dep" == "hyprland" ]]; then
            ver=$(hyprland --version | head -n 1 | awk '{print $3}')
            ok "$dep está instalado en $path_dep (Versión: $ver)"
        elif [[ "$dep" == "ags" ]]; then
            ver=$(ags --version | head -n 1)
            ok "$dep está instalado en $path_dep (Versión: $ver)"
        else
            ok "$dep está instalado en $path_dep"
        fi
    else
        err "$dep NO está instalado o no se encuentra en \$PATH"
    fi
done

# 3. Comprobación de Portales XDG (Compartición de pantalla y diálogos)
echo ""
info "Comprobando portales de escritorio XDG (XDG Desktop Portals)..."
if pgrep -x "xdg-desktop-por" &>/dev/null; then
    ok "xdg-desktop-portal principal está ejecutándose."
else
    err "xdg-desktop-portal NO está corriendo. La compartición de pantalla y selectores de archivos fallarán."
fi

if pgrep -f "xdg-desktop-portal-hyprland" &>/dev/null; then
    ok "xdg-desktop-portal-hyprland está ejecutándose."
else
    err "xdg-desktop-portal-hyprland NO está corriendo. La captura de pantalla en Wayland fallará."
fi

PORTAL_CONF="$HOME/.config/xdg-desktop-portal/portals.conf"
if [[ -f "$PORTAL_CONF" ]]; then
    ok "Archivo de portales existe: $PORTAL_CONF"
    if grep -q "default=" "$PORTAL_CONF"; then
        ok "El archivo define portales predeterminados correctamente."
    else
        warn "El archivo $PORTAL_CONF existe pero no define 'default=...'"
    fi
else
    warn "No existe portals.conf en $PORTAL_CONF. Es recomendable para acelerar la apertura de apps en Wayland."
fi

# 4. Comprobación de Demonios y Servicios de Fondo propios
echo ""
info "Verificando demonios de fondo activos..."
if pgrep -f "monitor-manager.sh" &>/dev/null; then
    ok "Gestor de hotplug de monitores (monitor-manager.sh) está corriendo."
else
    warn "El demonio automático de monitores (monitor-manager.sh) NO está ejecutándose."
fi

if pgrep -f "gjs.*ags" &>/dev/null || pgrep -x "ags" &>/dev/null; then
    ok "Barra y entorno AGS está corriendo."
else
    warn "AGS (barra/widgets) NO está ejecutándose."
fi

if pgrep -f "awww-daemon" &>/dev/null; then
    ok "Gestor de fondos de pantalla (awww-daemon) está corriendo."
else
    warn "El gestor de fondos (awww-daemon) NO está ejecutándose."
fi

# 5. Comprobación de GPU y Variables Nvidia
echo ""
info "Verificando GPU y controladores gráficos..."
GPUS=$(lspci | grep -iE 'vga|3d')
echo -e "GPU(s) Detectada(s):\n$GPUS"

if echo "$GPUS" | grep -iq "nvidia"; then
    info "GPU NVIDIA detectada. Comprobando controlador y variables..."
    if lsmod | grep -q nvidia; then
        ok "Módulo de kernel 'nvidia' cargado."
    else
        err "Módulo de kernel 'nvidia' NO está cargado."
    fi

    # Comprobación de variables críticas Nvidia
    ENV_VARS=(
        "GBM_BACKEND"
        "__GLX_VENDOR_LIBRARY_NAME"
        "LIBVA_DRIVER_NAME"
        "NVD_BACKEND"
    )
    for var in "${ENV_VARS[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            ok "Variable $var está configurada: ${!var}"
        else
            warn "Variable $var no está configurada (Recomendado para evitar glitches en Nvidia)."
        fi
    done
else
    ok "GPU no-Nvidia (Mesa/AMD/Intel) detectada. Sin requisitos especiales de variables de entorno."
fi

# 6. Monitores Conectados
echo ""
info "Monitores activos reportados por Hyprland:"
if command -v hyprctl &>/dev/null; then
    # Filtrar información básica de monitores
    hyprctl monitors | grep -E "Monitor|focused|geometry" || echo "No se detectaron monitores."
else
    err "No se pueden listar los monitores porque hyprctl no está disponible."
fi

echo -e "\n=== 🏥 DIAGNÓSTICO FINALIZADO ===\n"
