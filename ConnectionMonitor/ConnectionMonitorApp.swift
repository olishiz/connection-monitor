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

        // Hidden settings scene so the app can stay alive as a menu-bar agent.
        Settings {
            Form {
                Section("About") {
                    Text("Connection Monitor")
                        .font(.headline)
                    Text("Live ICMP ping status in your menu bar.")
                        .foregroundStyle(.secondary)
                    Text("Default target: google.com")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 320, height: 160)
            .padding()
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
