#!/bin/bash

PID_FILE="/tmp/wf_recording.pid"
STATUS_FILE="/tmp/wf_recording_status"
VIDEOS_DIR="$HOME/Videos"

# Asegurar que el directorio existe
mkdir -p "$VIDEOS_DIR"

stop_recording() {
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill -INT "$PID"
        notify-send -u normal -t 3000 -i media-record "Grabación Detenida" "Video guardado en la carpeta Videos."
    fi
    rm -f "$PID_FILE" "$STATUS_FILE"
}

start_recording() {
    local GEOMETRY="$1"
    FILENAME="$VIDEOS_DIR/Grabacion-$(date +%Y%m%d-%H%M%S).mp4"
    
    if [ -n "$GEOMETRY" ]; then
        wf-recorder -a -g "$GEOMETRY" -f "$FILENAME" > /tmp/wf-recorder.log 2>&1 &
        notify-send -u normal -t 3000 -i media-record "Grabación de Área Iniciada" "Capturando la zona seleccionada..."
    else
        wf-recorder -a -f "$FILENAME" > /tmp/wf-recorder.log 2>&1 &
        notify-send -u normal -t 3000 -i media-record "Grabación Iniciada" "Capturando pantalla completa..."
    fi
    
    PID=$!
    echo "$PID" > "$PID_FILE"
    echo "recording" > "$STATUS_FILE"
}

case "$1" in
    toggle)
        if [ -f "$PID_FILE" ]; then
            stop_recording
        else
            start_recording ""
        fi
        ;;
    toggle-region)
        if [ -f "$PID_FILE" ]; then
            stop_recording
        else
            # Usar slurp para seleccionar el área. Si el usuario presiona ESC, slurp falla y no graba.
            GEOMETRY=$(slurp 2>/dev/null)
            if [ -n "$GEOMETRY" ]; then
                start_recording "$GEOMETRY"
            fi
        fi
        ;;
    pause)
        if [ -f "$PID_FILE" ]; then
            STATUS=$(cat "$STATUS_FILE")
            PID=$(cat "$PID_FILE")
            
            if kill -0 "$PID" 2>/dev/null; then
                if [ "$STATUS" == "recording" ]; then
                    kill -STOP "$PID"
                    echo "paused" > "$STATUS_FILE"
                    notify-send -u normal -t 3000 -i media-playback-pause "Grabación Pausada" "La grabación está en pausa."
                elif [ "$STATUS" == "paused" ]; then
                    kill -CONT "$PID"
                    echo "recording" > "$STATUS_FILE"
                    notify-send -u normal -t 3000 -i media-record "Grabación Reanudada" "La grabación continúa."
                fi
            else
                rm -f "$PID_FILE" "$STATUS_FILE"
            fi
        else
            notify-send -u normal -t 3000 "Grabación" "No hay ninguna grabación en curso."
        fi
        ;;
    *)
        echo "Uso: $0 {toggle|toggle-region|pause}"
        ;;
esac
