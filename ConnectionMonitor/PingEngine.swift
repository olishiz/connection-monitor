import Foundation
import Combine

/// Continuously runs `/sbin/ping` against a host and publishes live samples.
@MainActor
final class PingEngine: ObservableObject {
    @Published private(set) var samples: [PingSample] = []
    @Published private(set) var stats = PingStats()
    @Published private(set) var status: ConnectionStatus = .idle
    @Published private(set) var isRunning = false
    @Published private(set) var resolvedIP: String?
    @Published var host: String = "google.com"
    @Published var intervalSeconds: Double = 1.0

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var lineBuffer = ""
    private let maxSamples = 200
    private var sequenceFallback = 0

    // Regexes for common macOS ping output
    // 64 bytes from 172.217.25.110: icmp_seq=5870 ttl=116 time=7.412 ms
    private let replyRegex = try! NSRegularExpression(
        pattern: #"(\d+)\s+bytes\s+from\s+([^\s:]+).*?icmp_seq[= ](\d+).*?(?:ttl[= ](\d+))?.*?time[= ]([\d.]+)\s*ms"#,
        options: [.caseInsensitive]
    )
    // PING google.com (172.217.25.110): 56 data bytes
    private let headerRegex = try! NSRegularExpression(
        pattern: #"PING\s+\S+\s+\(([^)]+)\)"#,
        options: [.caseInsensitive]
    )
    // Request timeout for icmp_seq 12
    private let timeoutRegex = try! NSRegularExpression(
        pattern: #"Request timeout for icmp_seq\s*(\d+)"#,
        options: [.caseInsensitive]
    )

    var menuBarText: String {
        if !isRunning { return "Ping" }
        return status.shortLabel
    }

    var statusIcon: String {
        status.systemImage
    }

    func start() {
        guard !isRunning else { return }
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            status = .error("Empty host")
            return
        }
        host = trimmed
        samples = []
        stats = PingStats()
        resolvedIP = nil
        sequenceFallback = 0
        status = .connecting
        isRunning = true
        launchPing(host: trimmed)
    }

    func stop() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        stdoutPipe = nil
        stderrPipe = nil
        lineBuffer = ""
        isRunning = false
        if case .error = status {
            // keep error
        } else {
            status = .idle
        }
    }

    func restart() {
        stop()
        start()
    }

    func clearLog() {
        samples = []
    }

    // MARK: - Process

    private func launchPing(host: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")

        // -i interval (seconds), continuous until killed
        // On macOS, fractional intervals may need root; 1s is safe.
        let interval = max(0.2, intervalSeconds)
        process.arguments = ["-i", String(format: "%.1f", interval), host]

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self else { return }
                // Unexpected exit while still marked running
                if self.isRunning {
                    self.isRunning = false
                    if proc.terminationStatus != 0 && proc.terminationStatus != 15 {
                        self.status = .error("ping exited (\(proc.terminationStatus))")
                    } else if case .connecting = self.status {
                        self.status = .error("Could not reach host")
                    }
                }
            }
        }

        do {
            try process.run()
            self.process = process
            self.stdoutPipe = out
            self.stderrPipe = err
            attachReader(out.fileHandleForReading)
            attachReader(err.fileHandleForReading)
        } catch {
            isRunning = false
            status = .error(error.localizedDescription)
        }
    }

    private func attachReader(_ handle: FileHandle) {
        handle.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.handleOutput(text)
            }
        }
    }

    private func handleOutput(_ chunk: String) {
        lineBuffer += chunk
        while let range = lineBuffer.range(of: "\n") {
            let line = String(lineBuffer[..<range.lowerBound])
            lineBuffer = String(lineBuffer[range.upperBound...])
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            parseLine(trimmed)
        }
    }

    private func parseLine(_ line: String) {
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)

        if let m = headerRegex.firstMatch(in: line, range: full),
           m.numberOfRanges >= 2,
           let r = Range(m.range(at: 1), in: line) {
            resolvedIP = String(line[r])
            return
        }

        if let m = replyRegex.firstMatch(in: line, range: full),
           m.numberOfRanges >= 6 {
            let ip = ns.substring(with: m.range(at: 2))
            let seq = Int(ns.substring(with: m.range(at: 3))) ?? 0
            var ttl: Int?
            if m.range(at: 4).location != NSNotFound {
                ttl = Int(ns.substring(with: m.range(at: 4)))
            }
            let timeMs = Double(ns.substring(with: m.range(at: 5))) ?? 0

            resolvedIP = ip
            let sample = PingSample(
                sequence: seq,
                host: host,
                resolvedIP: ip,
                latencyMs: timeMs,
                ttl: ttl,
                timestamp: Date(),
                isSuccess: true,
                errorMessage: nil
            )
            append(sample)
            stats.recordSuccess(timeMs)
            status = ConnectionStatus.from(latencyMs: timeMs)
            return
        }

        if let m = timeoutRegex.firstMatch(in: line, range: full) {
            let seq: Int
            if m.numberOfRanges >= 2, m.range(at: 1).location != NSNotFound {
                seq = Int(ns.substring(with: m.range(at: 1))) ?? sequenceFallback
            } else {
                sequenceFallback += 1
                seq = sequenceFallback
            }
            let sample = PingSample(
                sequence: seq,
                host: host,
                resolvedIP: resolvedIP,
                latencyMs: nil,
                ttl: nil,
                timestamp: Date(),
                isSuccess: false,
                errorMessage: line
            )
            append(sample)
            stats.recordFailure()
            status = .offline
            return
        }

        // Unknown / info lines ignored (e.g. statistics on exit)
        if line.localizedCaseInsensitiveContains("unknown host")
            || line.localizedCaseInsensitiveContains("cannot resolve")
            || line.localizedCaseInsensitiveContains("No route to host") {
            status = .error(line)
            stats.recordFailure()
            let sample = PingSample(
                sequence: sequenceFallback,
                host: host,
                resolvedIP: nil,
                latencyMs: nil,
                ttl: nil,
                timestamp: Date(),
                isSuccess: false,
                errorMessage: line
            )
            append(sample)
        }
    }

    private func append(_ sample: PingSample) {
        samples.append(sample)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }
}
