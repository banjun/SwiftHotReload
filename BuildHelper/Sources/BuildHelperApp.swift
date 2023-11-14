#if os(macOS)
import SwiftUI

/// to use: `swift run BuildHelper`
/// to debug: Build & Run BuildHelper target on SwiftHotReload.xcworkspace
/// NOTE: when run as an app, the app sandbox should be disabled to:
/// - monitor any file changes (to trigger build a swift file)
/// - run swiftc
@main
struct BuildHelperApp: SwiftUI.App {
    @ObservedObject private(set) var buildHelper = BuildHelper()

    var body: some Scene {
        Window("BuildHelper (\(String(ProcessInfo().processIdentifier)))", id: "Main") {
            ContentView()
                .environmentObject(buildHelper)
        }
        MenuBarExtra("BuildHelper", systemImage: "hammer.circle.fill") {
            Button("Show All") {
                // needs workaround: not works nicely when launched via `swift run BuildHelper`
                NSApp.unhide(nil)
            }
            Divider()
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
    }

    struct ContentView: View {
        @EnvironmentObject var buildHelper: BuildHelper

        var body: some View {
            VStack(spacing: 20) {
                Text("Monitored File" + "\n" + (buildHelper.monitoredFile?.path ?? "Nothing"))
                    .multilineTextAlignment(.center)

                Text("Date Reloaded" + "\n" + (buildHelper.dateReloaded?.formatted(date: .numeric, time: .complete) ?? "Never"))
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}
#endif
