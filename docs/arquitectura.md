# Arquitectura del Sistema de Cámaras Pi

## Casa (Jorge)

```
Starlink (Internet)
    │ CG-NAT 172.22.109.x / 129.222.59.x
    ▼
Linksys EA7300 v2 (stock firmware 2.0.4.216940)
    │ LAN: 172.22.109.250
    │ Static DNS 1: 5.175.245.8 (envía consultas *.naxclow.com al VPS)
    │ WiFi 2.4GHz: canal 6 fijo, 20MHz (para alcance máximo)
    │ WiFi 5GHz: canal 36 fijo
    │
    ├── Camára Xiaomi (thingino firmware) ─── IP: 10.88.88.5 (WireGuard)
    │   │  WiFi 2.4GHz
    │   │  Cámara apuntando a la entrada principal
    │   │  Usuario/Pass: thingino / Kimlinda.321
    │   │  RTSP: rtsp://10.88.88.5:554/ch0
    │   │  Firmware: thingino (open-source IP camera firmware)
    │   │
    ├── Cámara Sterem / Steren (Tuya) ─────── WiFi 2.4GHz
    │   │  Marca: Steren (CCTV 218)
    │   │  Protocolo: Tuya Smart (IoT cloud)
    │   │  App: Steren PRO (tuya-white)
    │   │  Cuenta: jorgelop1994@gmail.com (us-west)
    │   │  DeviceID: eb91478faedf680389ojxl
    │   │  Resolución: 1920×1080 H264
    │   │  Audio: G.711 μ-law
    │   │
    └── Cámara A9 spy (V720 app) ──────────── WiFi 2.4GHz
        │   Chip: BK7252
        │   Protocolo: Naxclow (propietario chino)
        │   App: V720
        │   UID: 080c0f08F473
        │   Resolución: 640×480 MJPEG
        │   DNS: *.naxclow.com → VPS (fake server)
        │   Nota: La cámara está en China / Starlink CG-NAT
        │         No se puede acceder directamente, solo mediante bridge
```

## Red

```
┌─────────────────────────────────────────────────────────────┐
│                     Starlink (Internet)                      │
│                    CG-NAT: 129.222.59.153                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│     Linksys EA7300 v2 (Router)    LAN: 172.22.109.250       │
│     DHCP: 172.22.109.x           Static DNS 1: 5.175.245.8  │
│     WiFi 2.4GHz (cameras) + 5GHz                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  VPS (5.175.245.8)                           │
│  ┌──────────┬──────────┬───────────┬──────────┬──────────┐  │
│  │ dnsmasq  │a9-bridge │tuya-bridge│ go2rtc   │WireGuard │  │
│  │ :53      │ :80,:6123│ :8554     │:1984,8555│ :51820   │  │
│  │          │          │           │ :8556    │          │  │
│  │ DNS para │ Fake Nax │ RTSP para │ Unifica  │ VPN para │  │
│  │ A9       │ clow srv │ Sterem    │ streams  │ Pixel/Mac│  │
│  └──────────┴──────────┴───────────┴──────────┴──────────┘  │
│                         │                                    │
└─────────────────────────┼────────────────────────────────────┘
                          │ WireGuard 10.88.88.1/24
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
    Pixel (10.88.88.2)  Mac (10.88.88.3) Xiaomi cam (10.88.88.5)
    Visor principal     Desarrollo        Thingino RTSP
```

## Flujo de cada cámara

### Xiaomi (thingino) — H264

```
Cámara (WiFi) ─RTSP→ Pixel (WireGuard) ─ffmpeg→ go2rtc ─WebRTC→ Dashboard
               10.88.88.5:554          RTSP relay         WS + UDP
```

- La cámara Xiaomi corre thingino (firmware abierto basado en OpenIPC)
- Envía RTSP H264 directamente
- ffmpeg en go2rtc lee el stream y lo pone a disposición vía WebRTC/MSE
- La Mac/Pixel se conectan vía WebSocket + UDP (WebRTC)

### Sterem (Tuya) — H264 + Audio

```
Cámara (WiFi) ─Tuya Cloud─→ tuya-bridge ─RTSP→ go2rtc ─WebRTC→ Dashboard
              P2P/WebRTC     :8554              WS + UDP
```

- La cámara Sterem usa protocolo Tuya (IoT cloud)
- tuya-bridge (seydx/tuya-ipc-terminal) establece sesión P2P con la cámara
- Convierte el stream a RTSP local en :8554
- go2rtc lo lee y lo sirve vía WebRTC
- **Problema resuelto**: dnsmasq bloqueaba systemd-resolved → DNS roto → tuya-bridge no podía conectar con Tuya Cloud

### A9 Spy (Naxclow) — MJPEG

```
Cámara (China/Starlink) ─TCP→ VPS :6123 ─HTTP MJPEG→ ffmpeg ─RTSP→ go2rtc ─WS→ Dashboard
                        DNS: *.naxclow.com  :80/snapshot                  mode=mjpeg
```

- La cámara A9 usa protocolo Naxclow (propietario chino)
- El router Linksys tiene Static DNS 1 = VPS → consultas *.naxclow.com van al VPS
- dnsmasq en VPS responde con la IP del VPS (5.175.245.8)
- a9-bridge (intx82/a9-v720) simula ser el servidor Naxclow
- La cámara se conecta al bridge vía TCP :6123 (keep-alive)
- Bridge expone HTTP :80 con /dev/UID/video (MJPEG) y /dev/UID/snapshot
- ffmpeg en go2rtc convierte HTTP MJPEG → RTSP interno
- **Importante**: no transcodificar, solo `-c copy` (MJPEG directo)
- El dashboard usa `mode=mjpeg` para mostrar el stream (no WebRTC)

## Servicios en el VPS

| Puerto | Servicio | Acceso | Propósito |
|---|---|---|---|
| 22 | SSH | Internet | Administración |
| 53 UDP/TCP | dnsmasq | Internet + WG | DNS para A9 |
| 80 TCP | a9-bridge | Internet + WG | HTTP MJPEG A9 |
| 1984 TCP | go2rtc web | WG solo | Interfaz web |
| 8555 TCP | go2rtc RTSP | WG solo | RTSP interno |
| 8556 TCP/UDP | go2rtc WebRTC | WG solo | WebRTC |
| 8554 TCP | tuya-bridge | localhost | RTSP Sterem |
| 6123 TCP/UDP | a9-bridge | Internet + WG | Control A9 |
| 51820 UDP | WireGuard | Internet | VPN |

## Dashboard

Página web simple con cuadrícula 2×2:

```
┌─────────────┬─────────────┐
│   Xiaomi    │     A9      │
│  (WebRTC)   │  (MJPEG img) │
├─────────────┼─────────────┤
│   Sterem    │     —       │
│  (WebRTC)   │   (vacío)   │
└─────────────┴─────────────┘
```

- **Xiaomi y Sterem**: iframes a go2rtc stream.html con WebRTC
- **A9**: iframe a go2rtc stream.html con `mode=mjpeg`
- Acceso: `http://5.175.245.8/dashboard.html` (desde cualquier lugar)
- Acceso local: `http://10.88.88.1:1984/stream.html?src=xiaomi&src=steren&src=a9&mode=&mode=&mode=mjpeg&width=50%25`

## Notas importantes

1. **Starlink CG-NAT**: No hay IP pública fija. WireGuard usa el VPS como relay.
2. **Stock firmware**: El Linksys EA7300 v2 NO tiene OpenWrt (firmware firmado, no se pudo instalar).
3. **DNS es crítico**: dnsmasq debe escuchar SOLO en la IP externa (5.175.245.8 y 10.88.88.1).
   NO en 0.0.0.0:53 porque bloquea systemd-resolved en 127.0.0.53:53.
4. **MJPEG no transcodificar**: Si go2rtc intenta transcodificar A9 (H264 desde MJPEG), introduce artefactos y alto CPU.
5. **Reconnect**: Todos los streams tienen `#reconnect=5` para reconexión automática.
6. **WiFi fijo**: Canal 6, 20MHz en 2.4GHz para máxima estabilidad con las cámaras.
