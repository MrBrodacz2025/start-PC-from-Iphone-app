import Foundation

struct TemperatureSensor: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let celsius: Double
    let kind: String

    var fahrenheit: Double { celsius * 9 / 5 + 32 }

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

struct TempsResponse: Codable {
    let status: String?
    let sensors: [TemperatureSensor]
    let count: Int?
    let source: String?
    let error: String?
}
