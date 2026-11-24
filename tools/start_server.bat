@echo off
rem Startet den Saint-Leonard-Server ohne Fenster. Weitere Optionen: --port=24680 --password=geheim --name="Mein Server" --max=16
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe
if not exist "%GODOT%" set GODOT=godot
"%GODOT%" --headless --path "%~dp0.." -- --server %*
pause
