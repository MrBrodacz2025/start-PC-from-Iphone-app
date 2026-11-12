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
            .navigationBarItems(
                leading: Button(action: { checkStatus() }) {
                    Image(systemName: "arrow.clockwise")
                },
                trailing: Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                }
            )
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear { checkStatus() }
        }
    }

    private func checkStatus() {
        guard !ipAddress.isEmpty,
              let url = URL(string: "http://\(ipAddress):\(port)/status") else {
            self.isOnline = nil
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3
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
