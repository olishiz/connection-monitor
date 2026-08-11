import Foundation
import SwiftUI

/// One successful or failed ping sample.
struct PingSample: Identifiable, Equatable {
    let id = UUID()
    let sequence: Int
    let host: String
    let resolvedIP: String?
    let latencyMs: Double?
    let ttl: Int?
    let timestamp: Date
    let isSuccess: Bool
    let errorMessage: String?

    var displayLine: String {
        if isSuccess, let latencyMs, let resolvedIP {
            let ttlPart = ttl.map { " ttl=\($0)" } ?? ""
            return String(
                format: "64 bytes from %@: icmp_seq=%d%@ time=%.3f ms",
                resolvedIP,
                sequence,
                ttlPart,
                latencyMs
            )
        }
        return errorMessage ?? "Request timeout for icmp_seq=\(sequence)"
    }
}

enum ConnectionStatus: Equatable {
    case idle
    case connecting
    case online(latencyMs: Double)
    case degraded(latencyMs: Double)
    case offline
    case error(String)

    var color: Color {
        switch self {
        case .idle:
            return Color(nsColor: .secondaryLabelColor)
        case .connecting:
            return Color(nsColor: .systemBlue)
        case .online:
            // Healthy — menu bar reads green at a glance
            return Color(nsColor: .systemGreen)
        case .degraded(let ms):
            // Slow but up: orange mid, red when very high
            return ms >= 150
                ? Color(nsColor: .systemRed)
                : Color(nsColor: .systemOrange)
        case .offline, .error:
            return Color(nsColor: .systemRed)
        }
    }

    var systemImage: String {
        switch self {
        case .idle: return "network"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .online: return "wifi"
        case .degraded: return "wifi.exclamationmark"
        case .offline: return "wifi.slash"
        case .error: return "exclamationmark.triangle"
        }
    }

    var shortLabel: String {
        switch self {
        case .idle: return "—"
        case .connecting: return "…"
        case .online(let ms):
            return ms < 10 ? String(format: "%.1f ms", ms) : String(format: "%.0f ms", ms)
        case .degraded(let ms):
            return ms < 10 ? String(format: "%.1f ms", ms) : String(format: "%.0f ms", ms)
        case .offline: return "Down"
        case .error: return "Err"
        }
    }

    /// Green &lt; 50ms · orange 50–149ms · red ≥ 150ms or offline.
    static func from(latencyMs: Double?) -> ConnectionStatus {
        guard let latencyMs else { return .offline }
        if latencyMs < 50 { return .online(latencyMs: latencyMs) }
        // Degraded carries the ms so color can go orange → red
        return .degraded(latencyMs: latencyMs)
    }
}

struct PingStats: Equatable {
    var sent: Int = 0
    var received: Int = 0
    var minMs: Double?
    var maxMs: Double?
    var totalMs: Double = 0

    var lossPercent: Double {
        guard sent > 0 else { return 0 }
        return Double(sent - received) / Double(sent) * 100
    }

    var averageMs: Double? {
        guard received > 0 else { return nil }
        return totalMs / Double(received)
    }

    mutating func recordSuccess(_ ms: Double) {
        sent += 1
        received += 1
        totalMs += ms
        minMs = min(minMs ?? ms, ms)
        maxMs = max(maxMs ?? ms, ms)
    }

    mutating func recordFailure() {
        sent += 1
    }
}
