#!/usr/bin/env bash

# Script para respaldar Profile 14 (hernanr@bluetrailsoft.com) de Brave y Chrome
# Excluyendo cachés pesadas para optimizar el tamaño.

BACKUP_DIR="${HOME}/bluetrail_browser_backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/bluetrail_profiles_backup_${TIMESTAMP}.tar.gz"

echo "=== Iniciando respaldo de perfiles de Blue Trail Software ==="
mkdir -p "$BACKUP_DIR"

# Archivo temporal para lista de exclusiones
EXCLUDE_FILE=$(mktemp)
cat <<EOF > "$EXCLUDE_FILE"
*Cache*
*Code Cache*
*GPUCache*
*Service Worker/CacheStorage*
*Service Worker/ScriptCache*
*Service Worker/Database*
*VideoDecodeStats*
*DawnCache*
*Session Storage*
EOF

echo "Creando empaquetado de respaldo en: $BACKUP_FILE"

# Crear el tar comprimido excluyendo archivos innecesarios
tar --exclude-from="$EXCLUDE_FILE" -czf "$BACKUP_FILE" \
    -C "${HOME}/.config/BraveSoftware/Brave-Browser" "Profile 14" \
    -C "${HOME}/.config/google-chrome" "Profile 14" 2>/dev/null || true

rm -f "$EXCLUDE_FILE"

if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    echo "¡Respaldo completado con éxito!"
    echo "Archivo: $BACKUP_FILE (Tamaño: $SIZE)"
else
    echo "Ocurrió un error al crear el archivo de respaldo."
fi
