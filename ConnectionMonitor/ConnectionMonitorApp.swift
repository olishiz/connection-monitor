import SwiftUI

@main
struct ConnectionMonitorApp: App {
    @StateObject private var engine = PingEngine()

    var body: some Scene {
        MenuBarExtra {
            PopoverRootView(engine: engine)
        } label: {
            MenuBarLabelView(engine: engine)
                .modifier(PingBootstrap(engine: engine))
        }
        .menuBarExtraStyle(.window)

        Settings {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connection Monitor")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("Live latency in your menu bar.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Default host · google.com")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 280, alignment: .leading)
            .padding(20)
        }
    }

}

/// Kicks off ping once the menu bar UI is alive.
private struct PingBootstrap: ViewModifier {
    @ObservedObject var engine: PingEngine

    func body(content: Content) -> some View {
        content
            .task {
                if !engine.isRunning {
                    engine.start()
                }
            }
    }
}
