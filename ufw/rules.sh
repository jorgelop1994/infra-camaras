#!/bin/bash
# Reglas UFW aplicadas en el VPS
# Puerto 53 abierto para DNS
ufw allow 53/udp
ufw allow 53/tcp
ufw allow 53/udp on wg0
ufw allow 53/tcp on wg0

# Puerto 80 (a9-bridge HTTP)
ufw allow 80/tcp

# go2rtc (solo WireGuard)
ufw allow in on wg0 to any port 1984 proto tcp
ufw allow in on wg0 to any port 8555 proto tcp
ufw allow in on wg0 to any port 8556 proto tcp
ufw allow in on wg0 to any port 8556 proto udp

# WireGuard (desde cualquier IP)
ufw allow 51820/udp

# SSH
ufw allow 22/tcp
