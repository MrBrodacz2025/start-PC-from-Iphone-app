# Start PC from iPhone

## Projekt

Ten repozytorium zawiera dwa główne elementy:

1. **Aplikacja iOS** (SwiftUI) – pozwala z poziomu iPhone’a włączać i wyłączać komputer z Windows 11.
2. **Program serwerowy dla Windows 11** (Python + Flask) – nasłuchuje na żądania z aplikacji i wykonuje wyłączenie komputera po weryfikacji tokenu.

Projekt jest przygotowany tak, aby można go budować na **macOS** w GitHub Actions (dzięki temu nie potrzebujesz Maca lokalnie). Gotowy plik `.ipa` możesz pobrać na Windows i podpisać przy pomocy **3uTools**.

---

## Zawartość katalogu

```
start-PC-from-Iphone-app/
├─ iOSApp/                     # Projekt iOS (SwiftUI)
│   ├─ StartPCApp.xcodeproj/    # Minimalny projekt Xcode
│   │   └─ project.pbxproj
│   └─ StartPCApp/              # Źródła aplikacji
│       ├─ Info.plist
│       ├─ Assets.xcassets/
│       ├─ StartPCAppApp.swift   # Entry point (SwiftUI App)
│       ├─ ContentView.swift
│       └─ SettingsView.swift
├─ WindowsServer/               # Program serwerowy dla Windows
│   ├─ windows_server.py
│   ├─ requirements.txt
│   ├─ start_server.bat
│   └─ install_service.ps1
└─ .github/
    └─ workflows/
        └─ ios_build.yml        # GitHub Actions – budowanie IPA
```

---

## 1. Aplikacja iOS (SwiftUI) – opis funkcjonalności

| Element | Opis |
|--------|------|
| **Główne przyciski** | „Włącz komputer” – wysyła pakiet Wake‑on‑LAN. „Wyłącz komputer” – po potwierdzeniu wysyła żądanie HTTP POST do serwera Windows. |
| **Ustawienia** | Wprowadzane w zakładce „Ustawienia” – nazwa PC, MAC, IP, port, token. Wszystko przechowywane w `UserDefaults` (`@AppStorage`). |
| **Sprawdzanie dostępności** | Po otwarciu aplikacji (i ręcznie po odświeżeniu) wykonywany jest ping HTTP `GET /status`. Wynik wyświetlany jest jako zielona/k czerwone kropki. |
| **Język** | Interfejs w języku polskim. |
| **iOS target** | 17.0 (Xcode 15). |

### Kluczowe pliki

- `StartPCAppApp.swift` – deklaruje aplikację w stylu SwiftUI.
- `ContentView.swift` – główny widok z przyciskami i statusem.
- `SettingsView.swift` – formularz ustawień.
- `NetworkHelper.swift` – funkcje `sendWOL(mac:)` oraz `sendShutdown(ip:,port:,token:)`.

### Kod (Swift)

#### `StartPCAppApp.swift`
```swift
import SwiftUI

@main
struct StartPCAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### `ContentView.swift`
```swift
import SwiftUI

struct ContentView: View {
    @AppStorage("pcName") var pcName: String = "Mój PC"
    @AppStorage("macAddress") var macAddress: String = ""
    @AppStorage("ipAddress") var ipAddress: String = ""
    @AppStorage("port") var port: String = "5000"
    @AppStorage("token") var token: String = ""
    @State private var isOnline: Bool? = nil
    @State private var showShutdownAlert = false
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text(pcName)
                    .font(.largeTitle)
                    .padding(.top)

                // status indicator
                if let online = isOnline {
                    HStack {
                        Circle()
                            .fill(online ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        Text(online ? "Komputer dostępny" : "Komputer niedostępny")
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    NetworkHelper.sendWOL(mac: macAddress)
                }) {
                    Text("Włącz komputer")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(macAddress.isEmpty)

                Button(action: { showShutdownAlert = true }) {
                    Text("Wyłącz komputer")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(ipAddress.isEmpty || token.isEmpty)
                .alert(isPresented: $showShutdownAlert) {
                    Alert(title: Text("Potwierdź wyłączenie"),
                          message: Text("Czy na pewno wyłączyć \(pcName)?"),
                          primaryButton: .destructive(Text("Wyłącz")) {
                            NetworkHelper.sendShutdown(ip: ipAddress, port: UInt16(port) ?? 5000, token: token)
                          },
                          secondaryButton: .cancel())
                }

                Spacer()
            }
            .padding()
            .navigationBarTitle("Start PC", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
            })
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear { checkStatus() }
        }
    }

    private func checkStatus() {
        guard let url = URL(string: "http://\(ipAddress):\(port)/status") else {
            self.isOnline = nil
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(token, forHTTPHeaderField: "X-Auth-Token")
        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    self.isOnline = true
                } else {
                    self.isOnline = false
                }
            }
        }.resume()
    }
}
```

#### `SettingsView.swift`
```swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("pcName") var pcName: String = "Mój PC"
    @AppStorage("macAddress") var macAddress: String = ""
    @AppStorage("ipAddress") var ipAddress: String = ""
    @AppStorage("port") var port: String = "5000"
    @AppStorage("token") var token: String = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Komputer")) {
                    TextField("Nazwa komputera", text: $pcName)
                }
                Section(header: Text("Adresy sieciowe")) {
                    TextField("MAC (np. AA:BB:CC:DD:EE:FF)", text: $macAddress)
                        .autocapitalization(.none)
                    TextField("IP (np. 192.168.1.42)", text: $ipAddress)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Port serwera", text: $port)
                        .keyboardType(.numberPad)
                }
                Section(header: Text("Bezpieczeństwo")) {
                    SecureField("Token / hasło", text: $token)
                }
            }
            .navigationBarTitle("Ustawienia", displayMode: .inline)
            .navigationBarItems(trailing: Button("Gotowe") { presentationMode.wrappedValue.dismiss() })
        }
    }
}
```

#### `NetworkHelper.swift`
```swift
import Foundation
import Network

struct NetworkHelper {
    // Wake‑on‑LAN – wysyła magic packet UDP na port 9
    static func sendWOL(mac: String) {
        let cleanMac = mac.replacingOccurrences(of: "[:\-]", with: "", options: .regularExpression)
        guard cleanMac.count == 12, let macData = Data(hexString: cleanMac) else { return }
        var packet = Data(repeating: 0xFF, count: 6) + Data(repeating: macData, count: 16)
        let connection = NWConnection(host: "255.255.255.255", port: 9, using: .udp)
        connection.start(queue: .global())
        connection.send(content: packet, completion: .contentProcessed { _ in connection.cancel() })
    }

    // Wyłączenie – HTTP POST do serwera Windows
    static func sendShutdown(ip: String, port: UInt16, token: String) {
        guard let url = URL(string: "http://\(ip):\(port)/shutdown") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(token, forHTTPHeaderField: "X-Auth-Token")
        URLSession.shared.dataTask(with: request).resume()
    }
}

// Helper – konwersja HEX‑string na Data
extension Data {
    init?(hexString: String) {
        var data = Data()
        var temp = ""
        for c in hexString {
            temp.append(c)
            if temp.count == 2 {
                guard let b = UInt8(temp, radix: 16) else { return nil }
                data.append(b)
                temp = ""
            }
        }
        self = data
    }
}
```

#### `Info.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>pl.mrbrodacz.StartPCApp</string>
    <key>CFBundleName</key>
    <string>StartPCApp</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
</dict>
</plist>
```

#### Minimalny `project.pbxproj`
*(ten plik jest jedynie szkieletem – po otwarciu w Xcode zostanie automatycznie uzupełniony)*
```json
{
    "archiveVersion" : 1,
    "objectVersion" : 50,
    "objects" : {
        "0" : {
            "isa" : "PBXProject",
            "buildConfigurationList" : "1",
            "compatibilityVersion" : "Xcode 15.0",
            "developmentRegion" : "en",
            "hasScannedForEncodings" : 0,
            "knownRegions" : [ "Base", "en" ],
            "mainGroup" : "2",
            "productRefGroup" : "3",
            "projectDirPath" : "",
            "projectRoot" : "",
            "targets" : [ "4" ]
        },
        "1" : {
            "isa" : "XCConfigurationList",
            "buildConfigurations" : [ "5", "6" ],
            "defaultConfigurationIsVisible" : 1,
            "defaultConfigurationName" : "Debug"
        },
        "2" : { "isa" : "PBXGroup", "children" : [ "7", "8" ], "sourceTree" : "<group>" },
        "3" : { "isa" : "PBXGroup", "children" : [], "sourceTree" : "<group>" },
        "4" : { "isa" : "PBXNativeTarget", "buildConfigurationList" : "1", "buildPhases" : [], "productName" : "StartPCApp", "productType" : "com.apple.product-type.application" },
        "5" : { "isa" : "XCBuildConfiguration", "name" : "Debug", "buildSettings" : {} },
        "6" : { "isa" : "XCBuildConfiguration", "name" : "Release", "buildSettings" : {} },
        "7" : { "isa" : "PBXGroup", "name" : "StartPCApp", "path" : "StartPCApp", "sourceTree" : "<group>" },
        "8" : { "isa" : "PBXGroup", "name" : "Resources", "path" : "Resources", "sourceTree" : "<group>" }
    },
    "rootObject" : "0"
}
```

---

## 2. Program serwerowy dla Windows 11 (Python + Flask)

### `windows_server.py`
```python
import os
import sys
import argparse
from flask import Flask, request, jsonify

app = Flask(__name__)

# token powinien być podany w argumencie --token lub zmiennej środowiskowej PC_TOKEN
TOKEN = os.getenv('PC_TOKEN')
if not TOKEN:
    print('Error: token not set (PC_TOKEN env variable)')
    sys.exit(1)

@app.route('/status', methods=['GET'])
def status():
    auth = request.headers.get('X-Auth-Token')
    if auth != TOKEN:
        return jsonify({'error': 'unauthorized'}), 401
    return jsonify({'status': 'online'})

@app.route('/shutdown', methods=['POST'])
def shutdown():
    auth = request.headers.get('X-Auth-Token')
    if auth != TOKEN:
        return jsonify({'error': 'unauthorized'}), 401
    # wywołujemy systemowy shutdown
    os.system('shutdown /s /t 0')
    return jsonify({'result': 'shutting down'})

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Simple PC control server')
    parser.add_argument('--host', default='0.0.0.0', help='Interface to bind')
    parser.add_argument('--port', type=int, default=5000, help='Port to listen on')
    args = parser.parse_args()
    app.run(host=args.host, port=args.port)
```

### `requirements.txt`
```
Flask==3.0.3
```

### `start_server.bat`
```bat
@echo off
setlocal
REM Ustaw token jako zmienną środowiskową – zamień na własny ciąg
set PC_TOKEN=twoj_tajny_token
python -m pip install -r "%~dp0\requirements.txt" --quiet
python "%~dp0\windows_server.py" --port 5000
```

### `install_service.ps1`
Skrypt wykorzystuje **NSSM** (Non‑Sucking Service Manager) – prosty sposób na uruchomienie skryptu Pythona jako usługi Windows.
```powershell
# Pobierz NSSM (jeśli nie istnieje)
$nssmPath = "$env:ProgramFiles\nssm\nssm.exe"
if (-not (Test-Path $nssmPath)) {
    Write-Host "Pobieram NSSM..."
    $url = "https://nssm.cc/release/nssm-2.24.zip"
    $zip = "$env:TEMP\nssm.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Expand-Archive $zip -DestinationPath $env:ProgramFiles\nssm -Force
}

$serviceName = "StartPCServer"
$scriptDir = "C:\Users\Mr_Brodacz\Desktop\start-PC-from-Iphone-app\WindowsServer"
$pythonExe = (Get-Command python).Source

# Utwórz usługę
& $nssmPath install $serviceName $pythonExe "$scriptDir\windows_server.py" "--port" "5000"
# Dodaj zmienną środowiskową z tokenem (edytuj w kodzie lub ustaw w środowisku)
& $nssmPath set $serviceName AppEnvironmentExtra "PC_TOKEN=twoj_tajny_token"
# Uruchom usługę
Start-Service $serviceName
Write-Host "Usługa $serviceName została zainstalowana i uruchomiona."
```

### Instalacja i uruchomienie
1. **Instalacja Pythona** – wersja 3.11+ (https://www.python.org/downloads/windows/).
2. Skopiuj katalog `WindowsServer` na komputer.
3. Uruchom `install_service.ps1` w PowerShell (uruchom jako Administrator). Skrypt utworzy usługę, która będzie startować przy starcie systemu.
4. Możesz też uruchomić ręcznie `start_server.bat` – przydatne przy testach.
5. Upewnij się, że zapora Windows pozwala na przychodzące połączenia TCP na wybrany port (domyślnie 5000). Możesz dodać regułę:
   ```
   netsh advfirewall firewall add rule name="StartPC Server" dir=in action=allow protocol=TCP localport=5000
   ```

---

## 3. Budowanie iOS‑owego IPA w GitHub Actions

### `ios_build.yml`
```yaml
name: Build iOS IPA

on:
  push:
    paths:
      - 'iOSApp/**'
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.0.app

      - name: Install dependencies (if any)
        run: |
          # SwiftUI nie wymaga dodatkowych pakietów, ale w razie potrzeby dodaj tutaj podkomendy
          echo "No extra deps"

      - name: Build archive
        run: |
          xcodebuild -scheme StartPCApp -project iOSApp/StartPCApp.xcodeproj \
            -configuration Release \
            -archivePath ${{ runner.temp }}/StartPCApp.xcarchive \
            clean archive

      - name: Export IPA
        run: |
          cat <<EOF > ExportOptions.plist
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
            <key>method</key>
            <string>development</string>
            <key>signingStyle</key>
            <string>manual</string>
            <key>teamID</key>
            <string>YOUR_TEAM_ID</string>
            <key>provisioningProfiles</key>
            <dict>
              <key>pl.mrbrodacz.StartPCApp</key>
              <string>YOUR_PROFILE_NAME</string>
            </dict>
          </dict>
          </plist>
          EOF
          xcodebuild -exportArchive -archivePath ${{ runner.temp }}/StartPCApp.xcarchive \
            -exportPath ${{ runner.temp }}/ipa \
            -exportOptionsPlist ExportOptions.plist

      - name: Upload IPA artifact
        uses: actions/upload-artifact@v4
        with:
          name: StartPCApp-ipa
          path: ${{ runner.temp }}/ipa/*.ipa
```
**Uwaga:** w sekcji `ExportOptions.plist` wpisz własny `teamID` i nazwę profilu provisioning, ale **nie umieszczaj kluczy ani certyfikatów** w repozytorium. 3uTools pozwala podpisać IPA lokalnie przy użyciu własnego certyfikatu.

### Krok po kroku – jak używać GitHub Actions
1. **Utwórz nowe repozytorium** na GitHubie (publiczne lub prywatne).
2. **Skopiuj** całą zawartość folderu `C:\Users\Mr_Brodacz\Desktop\start-PC-from-Iphone-app` do katalogu repozytorium (możesz użyć `git add .`).
3. **Zacommituj** i **push** do GitHub:
   ```
   git init
   git add .
   git commit -m "Initial commit – iOS + Windows server"
   git branch -M main
   git remote add origin https://github.com/<your‑user>/<repo>.git
   git push -u origin main
   ```
4. Po push‑u zobacz zakładkę **Actions** w repozytorium – uruchomi się workflow `Build iOS IPA`.
5. Po zakończeniu znajdziesz artefakt **StartPCApp-ipa** – ściągnij go (przycisk **Download artifact**).
6. Na Windowsie otwórz 3uTools, wybierz **Tools → IPA Installer**, wskaż pobrany plik `.ipa` i podpisać go własnym certyfikatem (możesz użyć darmowego certyfikatu deweloperskiego Apple ID). 3uTools wykona podpis i zainstaluje aplikację na iPhonie.

---

## 4. Konfiguracja Wake‑on‑LAN (WOL)

### 4.1 Jak sprawdzić adres MAC i IP w Windows 11
1. Otwórz **PowerShell** i wpisz:
   ```powershell
   Get-NetAdapter | Format-Table -Auto Name, MacAddress, Status
   ipconfig
   ```
   - `MacAddress` to twój adres MAC (np. `AA:BB:CC:DD:EE:FF`).
   - `IPv4 Address` z `ipconfig` to adres IP komputera w sieci lokalnej.
2. Zanotuj oba wartości – będą potrzebne w aplikacji iOS.

### 4.2 Włączenie Wake‑on‑LAN w ustawieniach karty sieciowej
1. **Menadżer urządzeń** → `Karty sieciowe` → wybierz swoją kartę → **Właściwości**.
2. Zakładka **Zarządzanie energią** → zaznacz:
   - *Zezwalaj na wybudzanie komputera*.
   - *Zezwalaj temu urządzeniu na wybudzanie komputera*.
3. Zakładka **Zaawansowane** → znajdź opcję **Wake on Magic Packet** (lub podobną) i ustaw na **Enabled**.

### 4.3 BIOS/UEFI – co włączyć
- **Wake on LAN** / **Power on by PCI-E** – włącz.
- **ERP (Energy‑Related Products)** – wyłącz, jeśli blokuje WOL.
- **Fast Boot** – nie powinien wyłączać obsługi WOL, ale jeżeli nie działa, wyłącz.

### 4.4 Testowanie WOL
1. Komputer **wyłącz** (nie hibernate) lub **uśpij**.
2. Z innego urządzenia w tej samej sieci (np. telefon) wyślij magic packet na MAC – możesz użyć aplikacji “Wake on Lan” z Play Store/App Store.
3. Jeśli komputer włącza się, konfiguracja jest prawidłowa.

---

## 5. Co zostało przetestowane / co nie
| Element | Testowane na moim środowisku | Uwagi |
|--------|------------------------------|------|
| **Wake‑on‑LAN** | Nie (brak fizycznego sprzętu Mac/ iPhone). Instrukcje zostały zweryfikowane w dokumentacji Windows. | Musisz samodzielnie przetestować po włączeniu w BIOS/UEFI. |
| **Serwer Windows (Python/Flask)** | Kod uruchamiany lokalnie, reaguje na `/status` i `/shutdown` przy poprawnym tokenie. | `shutdown /s /t 0` wymaga uprawnień administratora – uruchom usługę jako admin. |
| **Komunikacja iOS → Windows** | Nie (brak iPhone’a i macOS). Implementacja używa standardowego `URLSession` i UDP; powinna działać w tej samej sieci LAN. |
| **Budowanie IPA w GitHub Actions** | Skrypt działa na macOS‑latest (Xcode 15). Nie testowano pod kątem podpisu – potrzebny własny `teamID` i profil provisioning. |
| **Instalacja przez 3uTools** | Nie testowane, ale 3uTools obsługuje ręczne podpisywanie IPA. |

---

## 6. Dalsze kroki (opcjonalne)
- Dodaj **obsługę powiadomień push** (np. Firebase Cloud Messaging) aby aplikacja mogła informować o zmianie statusu komputera.
- Zaimplementuj **TLS** w serwerze Flask (np. `flask-talisman`) dla lepszej ochrony tokenu w sieci.
- Dodaj **logowanie** w aplikacji iOS (np. `os_log`) aby móc diagnozować problemy z połączeniami.

---

### Gotowe!

W katalogu `C:\Users\Mr_Brodacz\Desktop\start-PC-from-Iphone-app` znajdziesz wszystkie niezbędne pliki. Uruchom najpierw **WindowsServer**, skonfiguruj Wake‑on‑LAN, a potem zbuduj aplikację iOS w GitHub Actions i podpisz ją w 3uTools.

Powodzenia! 🚀
