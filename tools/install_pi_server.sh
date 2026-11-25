#!/bin/sh
# Richtet den Saint-Leonard-Server als Dienst ein (Raspberry Pi OS 64-bit oder anderes Linux).
# Aufruf im entpackten Server-Ordner:  sudo sh install_pi_server.sh
# Danach läuft der Server rund um die Uhr und startet nach einem Neustart von selbst.
set -e
BIN=$(ls saint_leonard_server.* 2>/dev/null | head -n 1)
if [ -z "$BIN" ]; then
  echo "Server-Datei (saint_leonard_server.arm64 oder .x86_64) nicht gefunden"; exit 1
fi
id saintleonard >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin saintleonard
mkdir -p /opt/saint-leonard
cp "$BIN" /opt/saint-leonard/saint_leonard_server
chmod +x /opt/saint-leonard/saint_leonard_server
chown -R saintleonard:saintleonard /opt/saint-leonard
cp saint-leonard-server.service /etc/systemd/system/saint-leonard-server.service
systemctl daemon-reload
systemctl enable --now saint-leonard-server
echo "Fertig. Status: systemctl status saint-leonard-server   Log: journalctl -u saint-leonard-server -f"
echo "Spielstände und server.cfg: /home/saintleonard/.local/share/godot/app_userdata/Saint-Leonard/"
echo "Port 24680 (UDP) im Router freigeben oder ZeroTier verwenden."
