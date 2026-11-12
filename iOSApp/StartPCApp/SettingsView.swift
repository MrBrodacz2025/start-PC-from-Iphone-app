import SwiftUI

struct SettingsView: View {
    @AppStorage("pcName") private var pcName: String = "Mój PC"
    @AppStorage("macAddress") private var macAddress: String = ""
    @AppStorage("ipAddress") private var ipAddress: String = ""
    @AppStorage("port") private var port: String = "5000"
    @AppStorage("token") private var token: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                Form {
                    Section("Komputer") {
                        TextField("Nazwa komputera", text: $pcName)
                    }

                    Section("Adresy sieciowe") {
                        TextField("MAC (np. AA:BB:CC:DD:EE:FF)", text: $macAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("IP (np. 192.168.1.42)", text: $ipAddress)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Port serwera", text: $port)
                            .keyboardType(.numberPad)
                    }

                    Section("Bezpieczeństwo") {
                        SecureField("Token / hasło", text: $token)
                    }

                    Section {
                        Text("Temperatury są pobierane z endpointu /temps na PC. Dla CPU/GPU/dysków uruchom LibreHardwareMonitor (z WMI).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Ustawienia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
