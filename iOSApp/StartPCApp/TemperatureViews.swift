import SwiftUI

struct TemperaturePanel: View {
    let sensors: [TemperatureSensor]
    let isLoading: Bool
    let errorMessage: String?
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Temperatury", systemImage: "thermometer.medium")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                }
                .liquidGlassButton()
                .disabled(isLoading)
            }

            if isLoading && sensors.isEmpty {
                ProgressView("Odczyt sensorów…")
                    .tint(.white)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else if let errorMessage, sensors.isEmpty {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            } else if sensors.isEmpty {
                Text("Brak odczytów. Zainstaluj LibreHardwareMonitor na PC dla pełnych danych CPU/GPU/dysk.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 12) {
                        sensorGrid
                    }
                } else {
                    sensorGrid
                }
            }
        }
        .padding(18)
        .liquidGlass(cornerRadius: 28)
    }

    private var sensorGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(sensors) { sensor in
                TemperatureSensorCard(sensor: sensor)
            }
        }
    }
}

struct TemperatureSensorCard: View {
    let sensor: TemperatureSensor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .foregroundStyle(accent)
                Text(sensor.level.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
            }

            Text(String(format: "%.0f°", sensor.celsius))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text(sensor.name)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .liquidGlass(cornerRadius: 20, interactive: true)
    }

    private var iconName: String {
        let lower = sensor.name.lowercased()
        if sensor.kind == "gpu" || lower.contains("gpu") {
            return "memorychip"
        }
        if lower.contains("cpu") || lower.contains("core") {
            return "cpu"
        }
        if lower.contains("dysk") || lower.contains("ssd") || lower.contains("nvme") {
            return "internaldrive"
        }
        return "thermometer.medium"
    }

    private var accent: Color {
        switch sensor.level {
        case .cool: return .cyan
        case .warm: return .yellow
        case .hot: return .orange
        case .critical: return .red
        }
    }
}
