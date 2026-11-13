$ErrorActionPreference = 'Stop'
$lib = Join-Path $PSScriptRoot 'tools\LibreHardwareMonitor\LibreHardwareMonitorLib.dll'
Add-Type -Path $lib

$computer = New-Object LibreHardwareMonitor.Hardware.Computer
$computer.IsCpuEnabled = $true
$computer.IsGpuEnabled = $true
$computer.IsMotherboardEnabled = $true
$computer.IsMemoryEnabled = $true
$computer.IsStorageEnabled = $true
$computer.Open()

function Update-All {
    foreach ($hw in $computer.Hardware) {
        $hw.Update()
        foreach ($sub in $hw.SubHardware) { $sub.Update() }
    }
}

# Kilka cykli Update – pierwsze odczyty AMD bywają zerowe
Update-All
Start-Sleep -Milliseconds 700
Update-All
Start-Sleep -Milliseconds 700
Update-All

$items = New-Object System.Collections.Generic.List[object]

function Collect-Sensors($hardware, $rootName) {
    foreach ($sensor in $hardware.Sensors) {
        if ($sensor.SensorType.ToString() -eq 'Temperature' -and $null -ne $sensor.Value) {
            $c = [double]$sensor.Value
            if ($c -gt 1 -and $c -le 120) {
                $items.Add([PSCustomObject]@{
                    name     = [string]$sensor.Name
                    hardware = [string]$rootName
                    celsius  = [math]::Round($c, 1)
                }) | Out-Null
            }
        }
    }
    foreach ($sub in $hardware.SubHardware) {
        Collect-Sensors $sub $rootName
    }
}

foreach ($hw in $computer.Hardware) {
    Collect-Sensors $hw $hw.Name
}

$computer.Close()
$items | ConvertTo-Json -Compress -Depth 4
