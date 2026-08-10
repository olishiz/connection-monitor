import SwiftUI
import Charts

struct MenuBarLabelView: View {
    @ObservedObject var engine: PingEngine

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: engine.statusIcon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(engine.status.color)
            Text(engine.menuBarText)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .monospacedDigit()
        }
    }
}

struct PopoverRootView: View {
    @ObservedObject var engine: PingEngine
    @State private var hostField: String = "google.com"
    @FocusState private var hostFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            statsRow
            Divider()
            latencyChart
            Divider()
            liveLog
            Divider()
            controls
        }
        .frame(width: 420, height: 520)
        .onAppear {
            hostField = engine.host
            if !engine.isRunning {
                engine.start()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(engine.status.color)
                .frame(width: 10, height: 10)
                .shadow(color: engine.status.color.opacity(0.6), radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("Live Connection")
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(engine.host)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let ip = engine.resolvedIP {
                        Text("→ \(ip)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            statusBadge
        }
        .padding(14)
    }

    private var statusBadge: some View {
        Text(statusTitle)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(engine.status.color.opacity(0.15))
            .foregroundStyle(engine.status.color)
            .clipShape(Capsule())
    }

    private var statusTitle: String {
        switch engine.status {
        case .idle: return "Idle"
        case .connecting: return "Connecting"
        case .online: return "Online"
        case .degraded: return "Degraded"
        case .offline: return "Offline"
        case .error: return "Error"
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(title: "Current", value: currentLatencyText)
            statCell(title: "Avg", value: formatOptionalMs(engine.stats.averageMs))
            statCell(title: "Min", value: formatOptionalMs(engine.stats.minMs))
            statCell(title: "Max", value: formatOptionalMs(engine.stats.maxMs))
            statCell(title: "Loss", value: String(format: "%.0f%%", engine.stats.lossPercent))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
    }

    private func statCell(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var currentLatencyText: String {
        if case .online(let ms) = engine.status { return formatMs(ms) }
        if case .degraded(let ms) = engine.status { return formatMs(ms) }
        if engine.isRunning { return "—" }
        return "—"
    }

    // MARK: - Chart

    private var latencyChart: some View {
        Group {
            if #available(macOS 14.0, *) {
                Chart {
                    ForEach(Array(engine.samples.suffix(60).enumerated()), id: \.element.id) { _, sample in
                        if let ms = sample.latencyMs {
                            LineMark(
                                x: .value("Seq", sample.sequence),
                                y: .value("ms", ms)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.accentColor)

                            AreaMark(
                                x: .value("Seq", sample.sequence),
                                y: .value("ms", ms)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.25), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                }
                .chartYAxisLabel("ms")
                .chartXAxis(.hidden)
                .frame(height: 80)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            } else {
                // Fallback sparkline-ish bars for older macOS
                GeometryReader { geo in
                    let recent = Array(engine.samples.suffix(40))
                    let maxMs = max(recent.compactMap(\.latencyMs).max() ?? 1, 1)
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(recent) { sample in
                            let h = sample.latencyMs.map { CGFloat($0 / maxMs) * geo.size.height } ?? 2
                            RoundedRectangle(cornerRadius: 1)
                                .fill(sample.isSuccess ? Color.accentColor.opacity(0.8) : Color.red.opacity(0.6))
                                .frame(width: max(2, (geo.size.width - 4) / CGFloat(max(recent.count, 1)) - 2), height: max(2, h))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(height: 80)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
    }

    // MARK: - Live log (terminal style)

    private var liveLog: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(engine.samples) { sample in
                        Text(sample.displayLine)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(sample.isSuccess ? Color.primary.opacity(0.9) : Color.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(sample.id)
                    }
                }
                .padding(10)
            }
            .background(Color.black.opacity(0.85))
            .foregroundStyle(.green)
            .onChange(of: engine.samples.count) { _, _ in
                if let last = engine.samples.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("Host or IP", text: $hostField)
                    .textFieldStyle(.roundedBorder)
                    .focused($hostFocused)
                    .onSubmit { applyHostAndRestart() }

                Button("Apply") {
                    applyHostAndRestart()
                }
                .disabled(hostField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack {
                if engine.isRunning {
                    Button {
                        engine.stop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .keyboardShortcut(".", modifiers: .command)
                } else {
                    Button {
                        engine.host = hostField.trimmingCharacters(in: .whitespacesAndNewlines)
                        engine.start()
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                }

                Button {
                    engine.clearLog()
                } label: {
                    Label("Clear", systemImage: "trash")
                }

                Spacer()

                Text("\(engine.stats.received)/\(engine.stats.sent) pkts")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(12)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func applyHostAndRestart() {
        let h = hostField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !h.isEmpty else { return }
        engine.host = h
        engine.restart()
    }

    private func formatMs(_ ms: Double) -> String {
        String(format: "%.1f ms", ms)
    }

    private func formatOptionalMs(_ ms: Double?) -> String {
        guard let ms else { return "—" }
        return formatMs(ms)
    }
}
