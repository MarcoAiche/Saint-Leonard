# Baut alle Versionen von Saint Leonard und packt sie für itch.io.
#
# Aufruf (PowerShell, im Projektordner):
#   .\tools\build_release.ps1                 # alle Plattformen, für die Export-Templates installiert sind
#   .\tools\build_release.ps1 -Upload         # zusätzlich zu itch.io hochladen (braucht butler, siehe docs/RELEASE.md)
#
# Ergebnis: build\itch\saint-leonard-<plattform>.zip
# Voraussetzungen: Godot 4.7.2 und die Export-Templates (Godot: Editor > Export-Vorlagen verwalten).

param(
    [switch]$Upload,
    [string]$Godot = "",
    [string]$ItchTarget = $env:ITCH_TARGET   # z. B. "marcoaiche/saint-leonard"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if ($Godot -eq "") {
    $Godot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
    if (-not (Test-Path $Godot)) { $Godot = "godot" }
}
$templates = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable"

# Preset, Template-Datei, Zielordner, itch.io-Kanal
$targets = @(
    @{ Preset = "Windows Desktop";      Template = "windows_release_x86_64.exe";  Dir = "build\windows";       Channel = "windows" },
    @{ Preset = "Linux";                Template = "linux_release.x86_64";        Dir = "build\linux";         Channel = "linux" },
    @{ Preset = "macOS";                Template = "macos.zip";                   Dir = "build\macos";         Channel = "mac" },
    @{ Preset = "Linux Server";         Template = "linux_release.x86_64";        Dir = "build\server";        Channel = "server-linux" },
    @{ Preset = "Raspberry Pi Server";  Template = "linux_release.arm64";         Dir = "build\server_arm64";  Channel = "server-raspberry-pi" }
)

# Welt einmal bauen, damit die fertige Welt (data/world_baked.scn) mitkommt und das Spiel schnell startet
Write-Host "Welt vorbereiten ..."
& $Godot --headless --path . --quit-after 120 | Out-Null

New-Item -ItemType Directory -Force "build\itch" | Out-Null
$built = @()
foreach ($t in $targets) {
    if (-not (Test-Path (Join-Path $templates $t.Template))) {
        Write-Host ("Übersprungen: {0} (Export-Template {1} fehlt)" -f $t.Preset, $t.Template) -ForegroundColor Yellow
        continue
    }
    Write-Host ("Baue {0} ..." -f $t.Preset)
    New-Item -ItemType Directory -Force $t.Dir | Out-Null
    $preset = Select-String -Path "export_presets.cfg" -Pattern ('^name="{0}"' -f [regex]::Escape($t.Preset)) -Quiet
    if (-not $preset) { throw ("Preset fehlt in export_presets.cfg: {0}" -f $t.Preset) }
    $out = (Get-Content "export_presets.cfg" | Select-String -Pattern 'export_path="([^"]*)"' -AllMatches | ForEach-Object { $_.Matches.Groups[1].Value }) |
        Where-Object { $_ -like ("{0}*" -f ($t.Dir -replace '\\', '/')) } | Select-Object -First 1
    & $Godot --headless --path . --export-release $t.Preset $out
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out)) { throw ("Export fehlgeschlagen: {0}" -f $t.Preset) }
    $zip = "build\itch\saint-leonard-{0}.zip" -f $t.Channel
    if ($out -like "*.zip") {
        Copy-Item $out $zip -Force
    } else {
        if ($t.Channel -like "server*") { Copy-Item "tools\saint-leonard-server.service", "tools\install_pi_server.sh" $t.Dir -Force }
        Compress-Archive -Path (Join-Path $t.Dir "*") -DestinationPath $zip -Force
    }
    $built += @{ Zip = $zip; Channel = $t.Channel }
    Write-Host ("  fertig: {0}" -f $zip) -ForegroundColor Green
}

if ($Upload) {
    if (-not $ItchTarget) { throw "Für den Upload -ItchTarget benutzer/spiel angeben oder ITCH_TARGET setzen (siehe docs/RELEASE.md)" }
    $version = (Select-String -Path "scripts\net\net.gd" -Pattern 'const VERSION := "([^"]*)"').Matches.Groups[1].Value
    foreach ($b in $built) {
        Write-Host ("Lade hoch: {0}:{1} (Version {2})" -f $ItchTarget, $b.Channel, $version)
        & butler push $b.Zip ("{0}:{1}" -f $ItchTarget, $b.Channel) --userversion $version
        if ($LASTEXITCODE -ne 0) { throw "butler push fehlgeschlagen" }
    }
}
Write-Host ("Fertig: {0} Versionen in build\itch" -f $built.Count)
