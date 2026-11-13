# Uruchamia LibreHardwareMonitor jako Administrator i włącza web API (port 8085)
$ErrorActionPreference = 'Stop'
$dir = Join-Path $PSScriptRoot 'tools\LibreHardwareMonitor'
$exe = Join-Path $dir 'LibreHardwareMonitor.exe'
$cfg = Join-Path $dir 'LibreHardwareMonitor.config'

@"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <appSettings>
    <add key="listenerEnabled" value="true" />
    <add key="listenerPort" value="8085" />
    <add key="listenerUrl" value="http://127.0.0.1:8085/" />
    <add key="minimizeToTray" value="true" />
    <add key="runMin" value="true" />
    <add key="startMin" value="true" />
    <add key="hidden" value="true" />
    <add key="runWebServerMenuItemChecked" value="true" />
  </appSettings>
</configuration>
"@ | Set-Content -Path $cfg -Encoding UTF8

Get-Process LibreHardwareMonitor -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Start-Process -FilePath $exe -WorkingDirectory $dir -WindowStyle Minimized
Write-Host "LibreHardwareMonitor started. W Options > Remote Web Server kliknij Run (raz)."
