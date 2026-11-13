import SwiftUI

struct MetricsPanel: View {
    let metrics: SystemMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Obciążenie", systemImage: "gauge.with.dots.needle.33percent")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            if let metrics {
                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 12) {
                        grid(metrics)
                    }
                } else {
                    grid(metrics)
                }
            } else {
                Text("Brak danych o obciążeniu.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(18)
        .liquidGlass(cornerRadius: 28)
    }

    private func grid(_ metrics: SystemMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(
                title: "CPU",
                value: percentText(metrics.cpu_percent),
                detail: metrics.cpu_freq_mhz.map { "\(Int($0)) MHz" } ?? "—",
                icon: "cpu",
                tint: .cyan
            )
            MetricCard(
                title: "RAM",
                value: percentText(metrics.ram_percent),
                detail: ramDetail(metrics),
                icon: "memorychip",
                tint: .mint
            )
            MetricCard(
                title: "Dysk C:",
                value: percentText(metrics.disk_percent),
                detail: diskDetail(metrics),
                icon: "internaldrive",
                tint: .orange
            )
            MetricCard(
                title: "GPU",
                value: percentText(metrics.gpu?.utilization_percent),
                detail: gpuDetail(metrics),
                icon: "cube",
                tint: .purple
            )
        }
    }

    private func percentText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value))%"
    }

    private func ramDetail(_ metrics: SystemMetrics) -> String {
        guard let used = metrics.ram_used_gb, let total = metrics.ram_total_gb else { return "—" }
        return String(format: "%.1f / %.0f GB", used, total)
    }

    private func diskDetail(_ metrics: SystemMetrics) -> String {
        guard let used = metrics.disk_used_gb, let total = metrics.disk_total_gb else { return "—" }
        return String(format: "%.0f / %.0f GB", used, total)
    }

    private func gpuDetail(_ metrics: SystemMetrics) -> String {
        if let used = metrics.gpu?.memory_used_mb, let total = metrics.gpu?.memory_total_mb {
            return String(format: "%.0f / %.0f MB", used, total)
        }
        return metrics.gpu?.name ?? "—"
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .liquidGlass(cornerRadius: 20, interactive: true)
    }
}

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
            } else if sensors.isEmpty {
                Text(errorMessage ?? "Brak temperatur. Uruchom LibreHardwareMonitor jako Administrator na PC.")
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
                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
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
        switch sensor.kind {
        case "gpu": return "cube"
        case "cpu": return "cpu"
        case "disk": return "internaldrive"
        case "board": return "rectangle.3.group"
        default: return "thermometer.medium"
        }
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
