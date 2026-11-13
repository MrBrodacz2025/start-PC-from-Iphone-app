import Foundation
import Network

enum NetworkHelper {
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

    static func postAction(path: String, ip: String, port: UInt16, token: String) {
        guard let url = URL(string: "http://\(ip):\(port)/\(path)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(token, forHTTPHeaderField: "X-Auth-Token")
        URLSession.shared.dataTask(with: request).resume()
    }

    static func sendShutdown(ip: String, port: UInt16, token: String) {
        postAction(path: "shutdown", ip: ip, port: port, token: token)
    }

    static func sendSleep(ip: String, port: UInt16, token: String) {
        postAction(path: "sleep", ip: ip, port: port, token: token)
    }

    static func checkStatus(ip: String, port: String, token: String) async -> Bool {
        guard let url = URL(string: "http://\(ip):\(port)/status") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3
        request.addValue(token, forHTTPHeaderField: "X-Auth-Token")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    static func fetchTemperatures(ip: String, port: String, token: String) async throws -> TempsResponse {
        guard let url = URL(string: "http://\(ip):\(port)/temps") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.addValue(token, forHTTPHeaderField: "X-Auth-Token")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(TempsResponse.self, from: data)
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
