#!/bin/bash
# Script para conectar de manera dinámica la cámara y micrófono del KVM a los dispositivos virtuales.

VIRTUAL_DEV="/dev/video10"

echo "Iniciando bucle de control multimedia para KVM..."

while true; do
    # Buscar el dispositivo de video físico de la REDRAGON
    PHYS_PATH=$(v4l2-ctl --list-devices 2>/dev/null | grep -A 1 "REDRAGON Live Camera" | tail -n 1 | xargs)

    if [ -n "$PHYS_PATH" ] && [ -e "$PHYS_PATH" ]; then
        echo "Cámara física encontrada en: $PHYS_PATH. Conectando..."

        # Intentar enlazar el audio en PipeWire
        # Nota: pw-link retornará error si ya están enlazados, redirigimos stderr a /dev/null
        pw-link "REDRAGON Live Camera Audio:capture_FL" "kvm_virtual_mic_input:playback_FL" 2>/dev/null
        pw-link "REDRAGON Live Camera Audio:capture_FR" "kvm_virtual_mic_input:playback_FR" 2>/dev/null

        # Transmitir video copiando el stream MJPEG directamente sin decodificar (ahorra mucha CPU)
        ffmpeg -loglevel warning -f v4l2 -input_format mjpeg -i "$PHYS_PATH" -codec:v copy -f v4l2 "$VIRTUAL_DEV"

        echo "Conexión terminada (dispositivo desconectado o error)."
    fi

    # Esperar 2 segundos antes de volver a verificar
    sleep 2
done
