import SwiftUI

struct ContentView: View {
    @AppStorage("pcName") private var pcName: String = "Mój PC"
    @AppStorage("macAddress") private var macAddress: String = ""
    @AppStorage("ipAddress") private var ipAddress: String = ""
    @AppStorage("port") private var port: String = "5000"
    @AppStorage("token") private var token: String = ""

    @State private var isOnline: Bool? = nil
    @State private var showShutdownAlert = false
    @State private var showSleepAlert = false
    @State private var showSettings = false
    @State private var sensors: [TemperatureSensor] = []
    @State private var metrics: SystemMetrics?
    @State private var tempsError: String?
    @State private var isLoadingTemps = false
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        headerCard
                        powerCard
                        MetricsPanel(metrics: metrics)
                        TemperaturePanel(
                            sensors: sensors,
                            isLoading: isLoadingTemps,
                            errorMessage: tempsError,
                            onRefresh: { Task { await refreshAll() } }
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Start PC")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("Potwierdź wyłączenie", isPresented: $showShutdownAlert) {
                Button("Anuluj", role: .cancel) {}
                Button("Wyłącz", role: .destructive) {
                    NetworkHelper.sendShutdown(
                        ip: ipAddress,
                        port: UInt16(port) ?? 5000,
                        token: token
                    )
                }
            } message: {
                Text("Czy na pewno wyłączyć \(pcName)?")
            }
            .alert("Uśpij komputer?", isPresented: $showSleepAlert) {
                Button("Anuluj", role: .cancel) {}
                Button("Uśpij") {
                    NetworkHelper.sendSleep(
                        ip: ipAddress,
                        port: UInt16(port) ?? 5000,
                        token: token
                    )
                }
            } message: {
                Text("\(pcName) przejdzie w tryb uśpienia. Wybudzisz go przyciskiem „Wybudź”.")
            }
            .task {
                await refreshAll()
                startAutoRefresh()
            }
            .onDisappear {
                refreshTask?.cancel()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var headerCard: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 10) {
                Text(pcName)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                        .shadow(color: statusColor.opacity(0.8), radius: 6)

                    Text(statusText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                }

                if let cpu = sensors.first(where: { $0.kind == "cpu" }) {
                    Text("CPU: \(Int(cpu.celsius))°C · \(Int(metrics?.cpu_percent ?? 0))%")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                } else if let hottest = sensors.first {
                    Text("Najcieplej: \(hottest.name) · \(Int(hottest.celsius))°C")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private var powerCard: some View {
        GlassCard(cornerRadius: 28) {
            VStack(spacing: 12) {
                Button {
                    NetworkHelper.sendWOL(mac: macAddress)
                } label: {
                    Label("Włącz / Wybudź", systemImage: "sun.max.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .liquidGlassProminentButton()
                .disabled(macAddress.isEmpty)
                .tint(.cyan)

                Button {
                    showSleepAlert = true
                } label: {
                    Label("Uśpij", systemImage: "moon.zzz.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .liquidGlassButton()
                .disabled(ipAddress.isEmpty || token.isEmpty || isOnline != true)
                .tint(.indigo)

                Button(role: .destructive) {
                    showShutdownAlert = true
                } label: {
                    Label("Wyłącz komputer", systemImage: "power")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .liquidGlassButton()
                .disabled(ipAddress.isEmpty || token.isEmpty)
                .tint(.red)
            }
        }
    }

    private var statusColor: Color {
        switch isOnline {
        case true: return .green
        case false: return .red
        case nil: return .gray
        }
    }

    private var statusText: String {
        switch isOnline {
        case true: return "Komputer dostępny"
        case false: return "Komputer niedostępny / uśpiony"
        case nil: return "Brak konfiguracji / sprawdzanie…"
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if Task.isCancelled { break }
                await refreshAll()
            }
        }
    }

    @MainActor
    private func refreshAll() async {
        guard !ipAddress.isEmpty else {
            isOnline = nil
            sensors = []
            metrics = nil
            tempsError = "Uzupełnij IP w ustawieniach."
            return
        }

        isLoadingTemps = true
        defer { isLoadingTemps = false }

        async let online = NetworkHelper.checkStatus(ip: ipAddress, port: port, token: token)
        isOnline = await online

        guard isOnline == true else {
            sensors = []
            metrics = nil
            tempsError = "Brak połączenia z serwerem."
            return
        }

        do {
            let response = try await NetworkHelper.fetchTemperatures(
                ip: ipAddress,
                port: port,
                token: token
            )
            sensors = response.sensors
            metrics = response.metrics
            if response.sensors.isEmpty {
                tempsError = response.error ?? response.hint ?? "Serwer nie zwrócił sensorów temperatury."
            } else {
                tempsError = response.hint
            }
        } catch {
            sensors = []
            metrics = nil
            tempsError = "Nie udało się pobrać danych."
        }
    }
}
