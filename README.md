# infra-cámaras

Infraestructura del sistema de cámaras Pi.

## Servicios (VPS `5.175.245.8`)

| Servicio | Puerto | Descripción |
|---|---|---|
| **dnsmasq** | `53` | DNS redirige `*.naxclow.com` → VPS (A9) |
| **a9-bridge** | `80`, `6123` | Fake server Naxclow para A9 spy camera |
| **tuya-bridge** | `8554` | RTSP bridge para cámara Sterem (Tuya) |
| **go2rtc** | `1984`, `8555`, `8556` | Unifica streams (Xiaomi, Sterem, A9) |
| **WireGuard** | `51820` | VPN para acceso desde Pixel/Mac |

## Estructura

```
infra-camaras/
├── dnsmasq/           # Config DNS (A9 camera)
├── go2rtc/            # Config go2rtc streams
├── docker/            # Docker Compose
├── tuya-bridge/       # Config tuya-bridge (Sterem)
├── dashboard/         # Página web cuadrícula 4-cámaras
├── a9-bridge/         # Servicio systemd a9-bridge
├── wireguard/         # Config WireGuard (template)
└── ufw/               # Reglas firewall
```

## Stack

- **Xiaomi**: thingino RTSP → ffmpeg → go2rtc
- **Sterem/Steren**: Tuya → tuya-bridge RTSP → go2rtc  
- **A9**: Naxclow protocol → a9-bridge HTTP → ffmpeg → go2rtc

## Documentación

- [`docs/arquitectura.md`](docs/arquitectura.md) — Topología de red, flujo de cada cámara, servicios, notas importantes
- [`docs/mejoras.md`](docs/mejoras.md) — Análisis de mejoras potenciales priorizadas

## Enlaces

- Dashboard: `http://5.175.245.8/dashboard.html`
- go2rtc multi: `http://10.88.88.1:1984/stream.html?src=xiaomi&src=steren&src=a9&mode=&mode=&mode=mjpeg&width=50%25`
