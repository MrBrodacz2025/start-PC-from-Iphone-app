import Foundation

struct TemperatureSensor: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let celsius: Double
    let kind: String

    var level: TempLevel {
        switch celsius {
        case ..<50: return .cool
        case ..<70: return .warm
        case ..<85: return .hot
        default: return .critical
        }
    }
}

enum TempLevel {
    case cool, warm, hot, critical

    var label: String {
        switch self {
        case .cool: return "OK"
        case .warm: return "Ciepło"
        case .hot: return "Gorąco"
        case .critical: return "Krytycznie"
        }
    }
}

struct GPUMetrics: Codable, Hashable {
    let name: String?
    let temperature_c: Double?
    let utilization_percent: Double?
    let memory_used_mb: Double?
    let memory_total_mb: Double?
}

struct SystemMetrics: Codable, Hashable {
    let cpu_percent: Double?
    let cpu_freq_mhz: Double?
    let ram_percent: Double?
    let ram_used_gb: Double?
    let ram_total_gb: Double?
    let disk_percent: Double?
    let disk_used_gb: Double?
    let disk_total_gb: Double?
    let uptime_seconds: Int?
    let gpu: GPUMetrics?
}

struct TempsResponse: Codable {
    let status: String?
    let sensors: [TemperatureSensor]
    let count: Int?
    let source: String?
    let error: String?
    let hint: String?
    let metrics: SystemMetrics?
}
