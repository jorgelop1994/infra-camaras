#!/bin/bash
# Loop recording: graba streams de cámaras en segmentos de 10 min
# Mantiene últimas 24h. Limpia segmentos viejos automáticamente.
# Uso: ./loop-record.sh start    # inicia todas las grabaciones
#      ./loop-record.sh stop     # detiene todo
#      ./loop-record.sh status   # estado actual

set -euo pipefail

BASE_DIR="/opt/camaras/recordings"
SEGMENT_SEC=$((10 * 60))        # 10 min por segmento
MAX_HOURS=24
MAX_SEGMENTS=$((MAX_HOURS * 60 / (SEGMENT_SEC / 60)))
PID_DIR="/tmp/loop-record"

# Streams: "nombre|url|transporte"
STREAMS=(
    "xiaomi|rtsp://thingino:Kimlinda.321@10.88.88.5:554/ch0|tcp"
    "steren|rtsp://127.0.0.1:8554/CCTV_218/hd|tcp"
    "a9|http://127.0.0.1:80/dev/080c0f08F473/video|"
)

name_of()  { echo "${1%%|*}"; }
url_of()   { local r="${1#*|}"; echo "${r%%|*}"; }
transp_of(){ local r="${1#*|}"; r="${r#*|}"; echo "$r"; }

ensure_dirs() {
    mkdir -p "$BASE_DIR" "$PID_DIR"
    for stream in "${STREAMS[@]}"; do
        mkdir -p "$BASE_DIR/$(name_of "$stream")"
    done
}

start_stream() {
    local spec="$1"
    local name=$(name_of "$spec")
    local url=$(url_of "$spec")
    local transport=$(transp_of "$spec")

    local pid_file="$PID_DIR/${name}.pid"
    local log_file="$BASE_DIR/${name}/record.log"

    [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null && return

    local ffmpeg_cmd=("ffmpeg" "-hide_banner" "-loglevel" "warning")
    if [ "$transport" = "tcp" ]; then
        ffmpeg_cmd+=("-rtsp_transport" "tcp")
    fi
    # reconnect flags solo para HTTP, no RTSP
    if [[ "$url" == http* ]]; then
        ffmpeg_cmd+=("-reconnect" "1" "-reconnect_at_eof" "1"
                     "-reconnect_streamed" "1" "-reconnect_delay_max" "10")
    fi
    ffmpeg_cmd+=("-timeout" "15000000"
                 "-i" "$url"
                 "-c" "copy"
                 "-f" "segment"
                 "-segment_time" "$SEGMENT_SEC"
                 "-segment_format" "mp4"
                 "-reset_timestamps" "1"
                 "-strftime" "1"
                 "-segment_atclocktime" "1"
                 "${BASE_DIR}/${name}/%Y%m%d_%H%M_${name}.mp4")

    # Loop restart: si ffmpeg se cae, reintenta cada 10s
    nohup bash -c 'while true; do "${ffmpeg_cmd[@]}" 2>> "$log_file"; echo "[loop] ffmpeg exited, restart in 10s..." >> "$log_file"; sleep 10; done' >> "$log_file" 2>&1 &
    local pid=$!
    echo "$pid" > "$pid_file"
    echo "  $name: iniciado (PID $pid)"
}

stop_stream() {
    local name="$1"
    local pid_file="$PID_DIR/${name}.pid"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        kill "$pid" 2>/dev/null && echo "  $name: detenido (PID $pid)" || echo "  $name: no corriendo"
        rm -f "$pid_file"
    fi
}

status_stream() {
    local name="$1"
    local pid_file="$PID_DIR/${name}.pid"
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        local size=$(du -sh "$BASE_DIR/$name" 2>/dev/null | cut -f1)
        echo "  $name: grabando (PID $(cat "$pid_file")), ${size:-0B} total"
    else
        echo "  $name: detenido"
    fi
}

cleanup_old() {
    local count=0
    for stream in "${STREAMS[@]}"; do
        local name=$(name_of "$stream")
        local dir="$BASE_DIR/$name"
        [ -d "$dir" ] || continue
        local files
        files=$(ls -1 "$dir"/*.mp4 2>/dev/null | sort | head -n -"$MAX_SEGMENTS")
        if [ -n "$files" ]; then
            while IFS= read -r f; do
                rm -f "$f"
                count=$((count + 1))
            done <<< "$files"
        fi
    done
    [ "$count" -gt 0 ] && echo "  limpiados $count segmentos viejos"
}

case "${1:-status}" in
    start)
        echo "Iniciando grabación loop..."
        ensure_dirs
        for stream in "${STREAMS[@]}"; do
            start_stream "$stream"
        done
        ;;
    stop)
        echo "Deteniendo grabación loop..."
        for stream in "${STREAMS[@]}"; do
            stop_stream "$(name_of "$stream")"
        done
        ;;
    status)
        echo "Estado de grabación loop:"
        for stream in "${STREAMS[@]}"; do
            status_stream "$(name_of "$stream")"
        done
        echo "Uso total: $(du -sh "$BASE_DIR" 2>/dev/null | cut -f1)"
        echo "Segmentos: $(find "$BASE_DIR" -name '*.mp4' 2>/dev/null | wc -l)"
        ;;
    cleanup)
        cleanup_old
        ;;
    *)
        echo "Uso: $0 {start|stop|status|cleanup}"
        exit 1
        ;;
esac
