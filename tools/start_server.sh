#!/bin/sh
# Startet den Saint-Leonard-Server (Linux, z. B. Raspberry Pi). Optionen: --port=24680 --password=geheim --name="Mein Server" --max=16
# GODOT zeigt auf die Godot-4.7.2-Datei (oder den exportierten Server).
GODOT=${GODOT:-godot}
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . -- --server "$@"
