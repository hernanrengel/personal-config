#!/bin/bash
set -euo pipefail

# Determinar el usuario real (por si se corre con sudo)
REAL_USER="${SUDO_USER:-$USER}"

if [[ "$EUID" -eq 0 && -z "${SUDO_USER:-}" ]]; then
    echo "ERROR: No corras este script directamente como root. Usa tu usuario normal."
    exit 1
fi

# 1. Comprobación de espacio en disco en la partición raíz (/)
echo "==> Comprobando espacio en disco..."
FREE_SPACE_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$FREE_SPACE_GB" -lt 3 ]; then
    echo "WARNING: Poco espacio en disco en / (${FREE_SPACE_GB}GB libres). Se recomiendan al menos 3GB."
    read -p "¿Deseas continuar con la actualización de todos modos? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Actualización cancelada por falta de espacio."
        exit 1
    fi
fi

# 2. Mostrar noticias de Arch Linux (útil para detectar cambios manuales requeridos)
if command -v python3 &>/dev/null; then
    echo "==> Últimas noticias de Arch Linux (revisa si hay intervenciones manuales requeridas):"
    python3 -c "
import urllib.request
import xml.etree.ElementTree as ET
try:
    url = 'https://archlinux.org/feeds/news/'
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        xml_data = response.read()
    root = ET.fromstring(xml_data)
    for item in root.findall('.//item')[:3]:
        title = item.find('title').text
        pubDate = item.find('pubDate').text
        print(f'  - {pubDate[:16]}: {title}')
except Exception:
    print('  No se pudieron cargar las noticias de Arch.')
"
fi

# 3. Actualizar el llavero de Arch Linux (archlinux-keyring) primero
# Esto previene errores de firma (PGP) comunes si el sistema lleva tiempo sin actualizarse.
echo "==> Actualizando el llavero de Arch (archlinux-keyring) para prevenir errores de firma..."
sudo pacman -Sy archlinux-keyring --noconfirm || echo "    Advertencia: No se pudo actualizar archlinux-keyring primero, continuando..."

# 3b. Refrescar la lista de mirrors si está vieja (>7 días) para evitar mirrors lentos/caídos
if command -v reflector &>/dev/null; then
    MIRRORLIST="/etc/pacman.d/mirrorlist"
    if [[ ! -f "$MIRRORLIST" ]] || [[ -n "$(find "$MIRRORLIST" -mtime +7 2>/dev/null)" ]]; then
        echo "==> Mirrorlist con más de 7 días; refrescando con reflector..."
        sudo cp "$MIRRORLIST" "${MIRRORLIST}.bak" 2>/dev/null || true
        sudo reflector --age 12 --protocol https --sort rate --latest 20 \
            --save "$MIRRORLIST" \
            || echo "    Advertencia: reflector falló, usando la mirrorlist actual."
    fi
else
    echo "==> (reflector no instalado; omitiendo refresco de mirrors. Instálalo con 'sudo pacman -S reflector' para mirrors siempre rápidos.)"
fi

echo "==> Actualizando base de datos de paquetes y sistema (pacman)..."
# Reintentar hasta 3 veces: un mirror lento a mitad de descarga aborta la transacción,
# pero los paquetes ya bajados quedan en caché, así que el reintento resume donde se cortó.
for intento in 1 2 3; do
    if sudo pacman -Syu --noconfirm; then
        break
    fi
    if [[ "$intento" -lt 3 ]]; then
        echo "==> pacman falló (intento ${intento}/3), reintentando en 5s..."
        sleep 5
    else
        echo "ERROR: pacman -Syu falló tras 3 intentos. Revisá tu conexión o la mirrorlist."
        exit 1
    fi
done

# qt5-webengine está en IgnorePkg de /etc/pacman.conf — no compilar
# (falla con kernel 6.x por incompatibilidad de headers de seccomp)

# Usar solo 2 jobs para compilación (seguro con 15 GB RAM)
export MAKEFLAGS="-j2"

if command -v yay &>/dev/null; then
    echo "==> Actualizando paquetes AUR con yay (revisa los diffs de PKGBUILD antes de compilar)..."
    # --answerdiff All: muestra el diff de cada PKGBUILD; sin --noconfirm yay
    # pide confirmacion tras la revision. Defensa contra paquetes AUR comprometidos.
    sudo -u "$REAL_USER" \
        nice -n 10 ionice -c 3 \
        yay -Syu --answerdiff All
elif command -v paru &>/dev/null; then
    echo "==> Actualizando paquetes AUR con paru (revisa los diffs de PKGBUILD antes de compilar)..."
    # --review: abre el diff de cada PKGBUILD para inspeccion manual antes de compilar.
    sudo -u "$REAL_USER" \
        nice -n 10 ionice -c 3 \
        paru -Syu --review
else
    echo "==> No se encontró helper AUR (yay/paru), omitiendo AUR."
fi

echo "==> Limpiando caché de paquetes (mantener últimas 2 versiones)..."
if command -v paccache &>/dev/null; then
    sudo paccache -rk2
else
    echo "    paccache no encontrado, omitiendo (instala pacman-contrib para activarlo)."
fi

echo "==> Eliminando paquetes huérfanos (si los hay)..."
orphans=$(pacman -Qdtq 2>/dev/null || true)
if [[ -n "$orphans" ]]; then
    echo "$orphans" | xargs sudo pacman -Rns --noconfirm
    echo "    Huérfanos eliminados."
else
    echo "    No hay huérfanos."
fi

# 4. Comprobación de archivos .pacnew y .pacsave sin fusionar
echo "==> Buscando archivos .pacnew y .pacsave sin fusionar..."
pacnew_files=$(find /etc -regextype posix-extended -regex ".+\.pac(new|save)" 2>/dev/null || true)
if [[ -n "$pacnew_files" ]]; then
    echo "    ATENCIÓN: Se encontraron archivos de configuración pendientes de revisión/fusión:"
    echo "$pacnew_files" | sed 's/^/      /'
    echo "    (Puedes usar la herramienta 'pacdiff' para gestionarlos)."
else
    echo "    No hay archivos .pacnew o .pacsave pendientes."
fi

# 5. Comprobación de servicios systemd fallidos
echo "==> Verificando si hay servicios de systemd fallidos..."
failed_services=$(systemctl --failed --quiet --no-legend || true)
if [[ -n "$failed_services" ]]; then
    echo "    ATENCIÓN: Se detectaron servicios de systemd fallidos:"
    systemctl --failed --no-legend | sed 's/^/      /'
else
    echo "    Todos los servicios de systemd están funcionando correctamente."
fi

echo ""
echo "Sistema actualizado correctamente."
