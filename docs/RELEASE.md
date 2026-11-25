# Release: itch.io-Builds und Server rund um die Uhr

## 1. Einmalig vorbereiten

1. **Export-Templates** für Godot 4.7.2 installieren: Godot-Editor, **Editor → Export-Vorlagen verwalten → Herunterladen und installieren**. Das lädt die Vorlagen für alle Plattformen (Windows, Linux, macOS, Raspberry Pi). Fehlt eine Plattform, überspringt das Build-Skript sie mit einem Hinweis.
2. Für den Upload: **butler** (das Upload-Programm von itch.io) installieren: https://itch.io/docs/butler/ , dann einmal `butler login` ausführen (öffnet den Browser, du meldest dich selbst an).
3. Auf itch.io das Spiel anlegen (z. B. `marcoaiche/saint-leonard`, Sichtbarkeit am Anfang "Draft" oder "Restricted" mit Download-Schlüsseln für Freunde).

## 2. Bauen

Im Projektordner (PowerShell):

```powershell
.\tools\build_release.ps1
```

Das Skript baut die Welt vor, exportiert jede Plattform und packt sie nach `build\itch\`:

| Datei | Inhalt |
|---|---|
| `saint-leonard-windows.zip` | Spiel für Windows (eine Exe) |
| `saint-leonard-linux.zip` | Spiel für Linux |
| `saint-leonard-mac.zip` | Spiel für macOS (nicht signiert: beim ersten Start Rechtsklick → Öffnen) |
| `saint-leonard-server-linux.zip` | Server für Linux-PCs und Mietserver |
| `saint-leonard-server-raspberry-pi.zip` | Server für den Raspberry Pi (64-bit Raspberry Pi OS) |

Die Export-Vorlagen dazu stehen in `export_presets.cfg` ("Windows Desktop", "Linux", "macOS", "Linux Server", "Raspberry Pi Server"). Die Kartendaten (`data/riegersdorf.json`) und die gebaute Welt kommen automatisch mit.

## 3. Hochladen zu itch.io

```powershell
.\tools\build_release.ps1 -Upload -ItchTarget marcoaiche/saint-leonard
```

Jede Plattform landet in einem eigenen itch.io-Kanal (`windows`, `linux`, `mac`, `server-linux`, `server-raspberry-pi`). Als Version wird `Net.VERSION` aus `scripts/net/net.gd` verwendet. Spiel und Server müssen dieselbe Version haben, sonst lehnt der Server die Verbindung ab; vor einem Release also `VERSION` erhöhen, wenn sich am Netzwerk etwas geändert hat.

## 4. Server auf dem Raspberry Pi

Voraussetzung: Raspberry Pi 4 oder 5 mit **64-bit** Raspberry Pi OS.

```sh
# auf dem Pi:
unzip saint-leonard-server-raspberry-pi.zip -d saint-leonard && cd saint-leonard
sudo sh install_pi_server.sh
```

Danach läuft der Server als Dienst `saint-leonard-server`, startet nach einem Neustart von selbst und wird bei einem Absturz neu gestartet.

| Was | Befehl / Ort |
|---|---|
| Status | `systemctl status saint-leonard-server` |
| Server-Meldungen live | `journalctl -u saint-leonard-server -f` |
| Neu starten | `sudo systemctl restart saint-leonard-server` |
| Einstellungen (Name, Passwort, Port, max. Spieler) | `/home/saintleonard/.local/share/godot/app_userdata/Saint-Leonard/server.cfg`, danach neu starten |
| Spielstände | im selben Ordner unter `saves/dedicated.json` |

Freunde verbinden sich mit der Adresse des Pi: im Heimnetz die lokale IP, von außen über ZeroTier (empfohlen) oder mit einer Portfreigabe für **24680 (UDP)** im Router.

Neue Version einspielen: neue Zip entpacken, `sudo sh install_pi_server.sh` erneut ausführen (Spielstände bleiben erhalten).

## 5. Server auf einem Windows-PC

`tools\start_server.bat` startet den Server aus dem Projektordner. Mit der exportierten Exe geht es auch ohne Godot: `SaintLeonard.exe --headless -- --server`.
