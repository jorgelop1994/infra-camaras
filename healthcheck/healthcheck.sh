#!/bin/bash
# Healthcheck del sistema de cámaras
# Monitorea servicios, streams, disco. Notifica por Telegram si algo falla.
# Uso: ./healthcheck.sh                    # ejecuta una vez
# Uso: ./healthcheck.sh --daemon           # loop cada 5 min

set -euo pipefail

TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-8695142214:AAESAksuFUA0GHeVUF9PTU_jDj9_Tpfh-WU}"
TELEGRAM_CHAT="${TELEGRAM_CHAT:-909838343}"
CHECK_INTERVAL=300  # 5 min

# Colores para log local
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

issues=()
alerts=()
last_alert_file="/tmp/healthcheck_last_alert"

send_alert() {
    local msg="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT}" \
        -d "text=${msg}" \
        -d "parse_mode=Markdown" > /dev/null
}

log_ok()  { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn(){ echo -e "  ${YELLOW}⚠${NC} $1"; issues+=("⚠️ $1"); }
log_err() { echo -e "  ${RED}✗${NC} $1"; issues+=("❌ $1"); }

check_systemd() {
    local svc="$1"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        log_ok "$svc: activo"
    else
        log_err "$svc: INACTIVO"
    fi
}

check_docker() {
    local container="$1"
    if docker ps --filter "name=${container}" --format "{{.Names}}" 2>/dev/null | grep -q .; then
        log_ok "docker $container: UP"
    else
        log_err "docker $container: DOWN"
    fi
}

check_endpoint() {
    local name="$1" url="$2" expected="$3"
    local result
    result=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
    if [ "$result" = "$expected" ]; then
        log_ok "$name: HTTP $result"
    else
        log_err "$name: esperado $expected, recibido $result"
    fi
}

check_go2rtc_stream() {
    local name="$1"
    local has_producer
    has_producer=$(curl -s "http://10.88.88.1:1984/api/streams" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); p=d.get('$name',{}).get('producers',[]); print('ok' if p else 'no')" 2>/dev/null || echo "err")
    case "$has_producer" in
        ok)  log_ok "go2rtc $name: streaming" ;;
        no)  log_warn "go2rtc $name: sin producer" ;;
        err) log_err "go2rtc $name: no responde" ;;
    esac
}

check_disk() {
    local usage
    usage=$(df / | awk 'NR==2{sub(/%/,"",$5); print $5}')
    if [ "$usage" -lt 80 ]; then
        log_ok "disco: ${usage}%"
    elif [ "$usage" -lt 90 ]; then
        log_warn "disco: ${usage}%"
    else
        log_err "disco: ${usage}% — casi lleno"
    fi
}

healthcheck() {
    issues=()
    echo "=== Healthcheck $(date '+%Y-%m-%d %H:%M:%S') ==="

    # ── Servicios ──
    check_systemd a9-bridge

    # ── Docker containers ──
    check_docker go2rtc
    check_docker tuya-bridge
    check_docker portero

    # ── Endpoints HTTP ──
    check_endpoint "a9-bridge HTTP" "http://127.0.0.1:80/dev/list" "200"
    check_endpoint "go2rtc API" "http://10.88.88.1:1984/api/streams" "200"

    # ── A9 camera conectada? ──
    local a9_count
    a9_count=$(curl -s "http://127.0.0.1:80/dev/list" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "0")
    if [ "$a9_count" -gt 0 ]; then
        log_ok "A9 camera: conectada ($a9_count dispositivos)"
    else
        log_err "A9 camera: NO conectada"
    fi

    # ── Streams go2rtc ──
    check_go2rtc_stream "xiaomi"
    check_go2rtc_stream "steren"
    check_go2rtc_stream "a9"

    # ── Disco ──
    check_disk

    # ── Notificar si hay issues nuevos ──
    if [ ${#issues[@]} -gt 0 ]; then
        local msg="🔴 *Healthcheck - Cámaras*\n"
        for issue in "${issues[@]}"; do
            msg+="\n${issue}"
        done

        # Solo notificar si cambió desde la última vez
        local new_hash
        new_hash=$(echo "${issues[@]}" | md5sum | cut -d' ' -f1)
        local last_hash=""
        [ -f "$last_alert_file" ] && last_hash=$(cat "$last_alert_file")

        if [ "$new_hash" != "$last_hash" ]; then
            echo -e "$msg" | head -1
            send_alert "$msg"
            echo "$new_hash" > "$last_alert_file"
        else
            echo "  (issues sin cambios desde último alert)"
        fi
    else
        echo -e "  ${GREEN}Todo OK${NC}"
        # Limpiar alerta anterior si todo bien
        rm -f "$last_alert_file"
    fi

    echo ""
}

# ── Main ──
if [ "${1:-}" = "--daemon" ]; then
    while true; do
        healthcheck
        sleep "$CHECK_INTERVAL"
    done
else
    healthcheck
fi
