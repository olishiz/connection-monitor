import SwiftUI
import Charts
import AppKit

// MARK: - Menu bar

struct MenuBarLabelView: View {
    @ObservedObject var engine: PingEngine

    var body: some View {
        // Rendered as an image so macOS menu bar keeps green / orange / red
        // (plain Text often gets forced monochrome in MenuBarExtra).
        Image(nsImage: MenuBarStatusImage.make(
            text: engine.menuBarText,
            color: NSColor(engine.status.color)
        ))
        .renderingMode(.original)
        .accessibilityLabel("Connection \(engine.menuBarText)")
    }
}

/// Tiny colored menu-bar glyph: ● 40ms
enum MenuBarStatusImage {
    static func make(text: String, color: NSColor) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let dot: CGFloat = 6
        let gap: CGFloat = 4
        let padX: CGFloat = 2
        let width = ceil(padX + dot + gap + textSize.width + padX)
        let height = max(ceil(textSize.height), 16)
        let size = NSSize(width: width, height: height)

        let image = NSImage(size: size, flipped: false) { rect in
            // Status dot
            let dotRect = NSRect(
                x: padX,
                y: (rect.height - dot) / 2,
                width: dot,
                height: dot
            )
            color.setFill()
            NSBezierPath(ovalIn: dotRect).fill()

            // Latency text
            let textOrigin = NSPoint(
                x: padX + dot + gap,
                y: (rect.height - textSize.height) / 2
            )
            (text as NSString).draw(at: textOrigin, withAttributes: attrs)
            return true
        }
        image.isTemplate = false
        return image
    }
}

// MARK: - Popover

struct PopoverRootView: View {
    @ObservedObject var engine: PingEngine
    @State private var hostField: String = "google.com"
    @FocusState private var hostFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            hero
            Divider().opacity(0.35)
            metrics
            chartSection
            historySection
            Divider().opacity(0.35)
            footer
        }
        .frame(width: 320)
        .background(.background)
        .onAppear {
            hostField = engine.host
            if !engine.isRunning {
                engine.start()
            }
        }
    }

    // MARK: Hero — large latency, quiet status

    private var hero: some View {
        VStack(spacing: 6) {
            Text(statusTitle.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(engine.status.color)
                .tracking(0.8)

            Text(heroLatency)
                .font(.system(size: 48, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.25), value: heroLatency)

            Text(heroUnit)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.tertiary)

            HStack(spacing: 6) {
                Text(engine.host)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                if let ip = engine.resolvedIP {
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text(ip)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .lineLimit(1)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .padding(.horizontal, 20)
    }

    private var heroLatency: String {
        switch engine.status {
        case .online(let ms), .degraded(let ms):
            return ms < 10 ? String(format: "%.1f", ms) : String(format: "%.0f", ms)
        case .connecting:
            return "…"
        case .offline, .error:
            return "—"
        case .idle:
            return "—"
        }
    }

    private var heroUnit: String {
        switch engine.status {
        case .online, .degraded:
            return "milliseconds"
        case .connecting:
            return "connecting"
        case .offline:
            return "no response"
        case .error:
            return "error"
        case .idle:
            return "not running"
        }
    }

    private var statusTitle: String {
        switch engine.status {
        case .idle: return "Idle"
        case .connecting: return "Connecting"
        case .online: return "Connected"
        case .degraded: return "Degraded"
        case .offline: return "Offline"
        case .error: return "Error"
        }
    }

    // MARK: Metrics — 4 quiet columns

    private var metrics: some View {
        HStack(spacing: 0) {
            metric("Avg", formatOptionalMs(engine.stats.averageMs))
            metricDivider
            metric("Min", formatOptionalMs(engine.stats.minMs))
            metricDivider
            metric("Max", formatOptionalMs(engine.stats.maxMs))
            metricDivider
            metric("Loss", String(format: "%.0f%%", engine.stats.lossPercent))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: 1, height: 28)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Chart — thin, soft

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latency")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 20)

            Group {
                if #available(macOS 14.0, *) {
                    Chart {
                        ForEach(Array(engine.samples.suffix(40)), id: \.id) { sample in
                            if let ms = sample.latencyMs {
                                LineMark(
                                    x: .value("t", sample.sequence),
                                    y: .value("ms", ms)
                                )
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                                .foregroundStyle(engine.status.color.opacity(0.85))

                                AreaMark(
                                    x: .value("t", sample.sequence),
                                    y: .value("ms", ms)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            engine.status.color.opacity(0.18),
                                            engine.status.color.opacity(0.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text("\(Int(v))")
                                        .font(.system(size: 9, design: .rounded))
                                        .foregroundStyle(.quaternary)
                                }
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.primary.opacity(0.05))
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: true))
                    .frame(height: 72)
                } else {
                    sparklineFallback
                        .frame(height: 72)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
        .padding(.top, 4)
    }

    private var sparklineFallback: some View {
        GeometryReader { geo in
            let recent = Array(engine.samples.suffix(40))
            let maxMs = max(recent.compactMap(\.latencyMs).max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(recent) { sample in
                    let h = sample.latencyMs.map { CGFloat($0 / maxMs) * geo.size.height } ?? 2
                    Capsule()
                        .fill(sample.isSuccess ? engine.status.color.opacity(0.45) : Color.red.opacity(0.35))
                        .frame(
                            width: max(2, (geo.size.width) / CGFloat(max(recent.count, 1)) - 2),
                            height: max(2, h)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    // MARK: History — clean list, not terminal green

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(engine.stats.received)/\(engine.stats.sent)")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 20)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(engine.samples.suffix(30).reversed()) { sample in
                            historyRow(sample)
                                .id(sample.id)
                        }
                    }
                }
                .frame(height: 140)
                .onChange(of: engine.samples.count) { _, _ in
                    if let first = engine.samples.suffix(30).reversed().first {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(first.id, anchor: .top)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 14)
    }

    private func historyRow(_ sample: PingSample) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(sample.isSuccess ? Color.green.opacity(0.85) : Color.red.opacity(0.85))
                .frame(width: 5, height: 5)

            Text(sample.isSuccess ? (sample.resolvedIP ?? engine.host) : "Timeout")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let ms = sample.latencyMs {
                Text(String(format: "%.1f ms", ms))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            } else {
                Text("—")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: Footer — host field + quiet actions

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)

                TextField("Host or IP", text: $hostField)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .focused($hostFocused)
                    .onSubmit { applyHostAndRestart() }

                if hostField.trimmingCharacters(in: .whitespacesAndNewlines) != engine.host
                    || hostFocused {
                    Button("Set") {
                        applyHostAndRestart()
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(hostField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )

            HStack(spacing: 16) {
                Button {
                    if engine.isRunning {
                        engine.stop()
                    } else {
                        engine.host = hostField.trimmingCharacters(in: .whitespacesAndNewlines)
                        engine.start()
                    }
                } label: {
                    Label(
                        engine.isRunning ? "Pause" : "Start",
                        systemImage: engine.isRunning ? "pause.fill" : "play.fill"
                    )
                }
                .keyboardShortcut(engine.isRunning ? "." : "r", modifiers: .command)

                Button {
                    engine.clearLog()
                } label: {
                    Label("Clear", systemImage: "trash")
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
                .foregroundStyle(.secondary)
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: Helpers

    private func applyHostAndRestart() {
        let h = hostField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !h.isEmpty else { return }
        hostFocused = false
        engine.host = h
        engine.restart()
    }

    private func formatOptionalMs(_ ms: Double?) -> String {
        guard let ms else { return "—" }
        if ms < 10 { return String(format: "%.1f", ms) }
        return String(format: "%.0f", ms)
    }
}
