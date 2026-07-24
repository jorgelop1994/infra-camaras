# Análisis de Mejoras Potenciales

> Estado actual: v1.0 — 3 cámaras funcionales, dashboard con recarga individual

## Categorías

- 🔴 **Alto impacto / poco esfuerzo** — prioridad
- 🟡 **Mediano** — buen valor pero más trabajo
- 🟢 **Bajo** — nice to have

---

## 🎨 Dashboard

| # | Mejora | Impacto | Esfuerzo | Notas |
|---|---|---|---|---|
| 1 | 🔴 **Audio Sterem en dashboard** | Alto | Bajo | La Sterem envía audio G.711 por RTSP. go2rtc ya lo sirve vía WebRTC (se ve en API). Solo falta habilitar el audio en el player. El iframe a stream.html incluiría audio automáticamente si el navegador lo permite |
| 2 | 🔴 **Snapshot button** | Alto | Bajo | Botón para descargar el frame actual de una cámara. Usar el endpoint `/api/frame` de go2rtc o el snapshot del bridge |
| 3 | 🟡 **Pantalla completa** | Medio | Bajo | Botón para expandir una cámara a pantalla completa (sin recargar). Útil para ver detalles |
| 4 | 🟡 **Indicador de frame rate** | Medio | Bajo | Mostrar FPS actual de cada stream (desde API de go2rtc) |
| 5 | 🟡 **Dashboard responsivo mobile** | Medio | Bajo | Optimizar para Pixel: gestos touch, botones más grandes |
| 6 | 🟢 **Layout configurable** | Bajo | Bajo | Permitir cambiar 2×2 a 1+3 o lista vertical |
| 7 | 🟢 **Dark/light automático** | Bajo | Mínimo | Seguir preferencia del sistema (`prefers-color-scheme`) |

---

## 📹 Cámaras

| # | Mejora | Impacto | Esfuerzo | Notas |
|---|---|---|---|---|
| 8 | 🔴 **A9: TCP mode** | Alto | Medio | El protocolo Naxclow soporta TCP. Cambiar `cap_live()` para solicitar TCP en lugar de UDP. Esto eliminaría pérdida de paquetes ≈ eliminaría artefactos |
| 9 | 🟡 **A9: reducir frame rate** | Medio | Bajo | Si la cámara permite configurar FPS, bajar de 25 a 10-15 para reducir uso de ancho de banda (importante en Starlink CG-NAT) |
| 10 | 🟡 **Sterem: sub-stream SD** | Medio | Bajo | El bridge ofrece `/CCTV_218/sd` (640×360). Para dashboard (vista previa) usar SD, para pantalla completa HD. Ahorra ancho de banda |
| 11 | 🟢 **Xiaomi: audio** | Bajo | Bajo | thingino soporta audio. Solo falta configurarlo en el stream de go2rtc |
| 12 | 🟢 **Night vision indicator** | Bajo | Bajo | Detectar si la cámara está en modo nocturno y mostrar icono |

---

## 🛡️ Infraestructura

| # | Mejora | Impacto | Esfuerzo | Notas |
|---|---|---|---|---|
| 13 | 🟡 **Healthcheck automático** | Alto | Medio | Script que monitorea: bridgge activo, cámara conectada, stream fluyendo, disco. Notifica por Telegram si algo falla |
| 14 | 🟡 **Regrabación local (loop)** | Medio | Medio | Grabación continua en anillo (últimas 24h) en disco del VPS. Útil para revisar eventos |
| 15 | 🟡 **Detección de movimiento** | Medio | Alto | Integrar motion detection (ej. con OpenCV o go2rtc). Actualmente no hay. Podría mandar snapshot por Telegram |
| 16 | 🟢 **Script de deploy** | Bajo | Bajo | `deploy.sh` que clona el repo y configura todo desde cero (útil si el VPS se cae) |
| 17 | 🟢 **Actualización automática** | Bajo | Bajo | Watchtower o cron para actualizar imágenes Docker (go2rtc, tuya-bridge) |

---

## 🤖 KOS / Portero

| # | Mejora | Impacto | Esfuerzo | Notas |
|---|---|---|---|---|
| 18 | 🟡 **Portero: snapshot por Telegram** | Medio | Medio | Cuando alguien toca el timbre, Portero envía snapshot de la cámara que apunta a la puerta (Xiaomi o Sterem) |
| 19 | 🟢 **Comando de voz "muéstrame la entrada"** | Bajo | Alto | Integrar KOS para que procese comandos de voz y muestre la cámara en el dashboard |
| 20 | 🟢 **Alertas de movimiento a Telegram** | Bajo | Alto | Cuando una cámara detecta movimiento, enviar video corto + notificación |

---

## Recomendación

### Hazlo ahora (esta sesión si quieres)
1. ✅ **A9 TCP mode** — eliminaría artefactos (#8)
2. ✅ **Audio Sterem** en dashboard (#1)
3. ✅ **Snapshot button** (#2)

### Próxima sesión
4. Dashboard responsivo mobile (#5)
5. Sub-stream SD para Sterem (#10)
6. Healthcheck (#13)

### Futuro
7. Detección de movimiento (#15)
8. Portero snapshots (#18)
9. Loop recording (#14)
