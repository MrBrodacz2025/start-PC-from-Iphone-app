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
                        .disableAutocorrection(true)
                    TextField("IP (np. 192.168.1.42)", text: $ipAddress)
                        .keyboardType(.numbersAndPunctuation)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
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
