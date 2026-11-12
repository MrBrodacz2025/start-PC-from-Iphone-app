import Foundation
import Network

struct NetworkHelper {
    /// Wake-on-LAN – wysyła magic packet UDP na port 9 (broadcast)
    static func sendWOL(mac: String) {
        let cleanMac = mac.replacingOccurrences(of: "[:\\-]", with: "", options: .regularExpression)
        guard cleanMac.count == 12, let macData = Data(hexString: cleanMac) else { return }

        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(macData)
        }

        let connection = NWConnection(
            host: NWEndpoint.Host("255.255.255.255"),
            port: NWEndpoint.Port(integerLiteral: 9),
            using: .udp
        )
        connection.start(queue: .global())
        connection.send(content: packet, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    /// Wyłączenie – HTTP POST do serwera Windows
    static func sendShutdown(ip: String, port: UInt16, token: String) {
        guard let url = URL(string: "http://\(ip):\(port)/shutdown") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(token, forHTTPHeaderField: "X-Auth-Token")
        URLSession.shared.dataTask(with: request).resume()
    }
}

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
        guard temp.isEmpty else { return nil }
        self = data
    }
}
