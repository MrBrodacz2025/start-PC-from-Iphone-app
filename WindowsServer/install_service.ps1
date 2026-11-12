# Pobierz NSSM (jeśli nie istnieje)
$nssmPath = "$env:ProgramFiles\nssm\nssm.exe"
if (-not (Test-Path $nssmPath)) {
    Write-Host "Pobieram NSSM..."
    $url = "https://nssm.cc/release/nssm-2.24.zip"
    $zip = "$env:TEMP\nssm.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Expand-Archive $zip -DestinationPath "$env:TEMP\nssm-extract" -Force
    $nssmExe = Get-ChildItem -Path "$env:TEMP\nssm-extract" -Recurse -Filter "nssm.exe" |
        Where-Object { $_.FullName -match "win64" } |
        Select-Object -First 1
    if (-not $nssmExe) {
        throw "Nie znaleziono nssm.exe w archiwum."
    }
    New-Item -ItemType Directory -Force -Path "$env:ProgramFiles\nssm" | Out-Null
    Copy-Item $nssmExe.FullName $nssmPath -Force
}

$serviceName = "StartPCServer"
$scriptDir = "C:\Users\Mr_Brodacz\Desktop\start-PC-from-Iphone-app\WindowsServer"
$pythonExe = (Get-Command python).Source

# Utwórz usługę
& $nssmPath install $serviceName $pythonExe "$scriptDir\windows_server.py" "--port" "5000"
# Token z pliku token.txt (nie commituj) albo placeholder
$tokenFile = Join-Path $scriptDir "token.txt"
if (Test-Path $tokenFile) {
    $token = (Get-Content $tokenFile -Raw).Trim()
} else {
    $token = "twoj_tajny_token"
}
& $nssmPath set $serviceName AppEnvironmentExtra "PC_TOKEN=$token"
& $nssmPath set $serviceName AppDirectory $scriptDir
# Uruchom usługę
Start-Service $serviceName
Write-Host "Usługa $serviceName została zainstalowana i uruchomiona."
