import SwiftUI
import SwiftHotReload

// NOTE: app sandbox is disabled to:
// - monitor any file changes (to trigger build a swift file)
// - run swiftc

// TODO: user consent on each connection to peers

@main
struct BuildHelperApp: App {
    @ObservedObject private(set) var buildHelper = BuildHelper()

    var body: some Scene {
        Window("BuildHelper (\(String(ProcessInfo().processIdentifier)))", id: "Main") {
            ContentView()
                .environmentObject(buildHelper)
        }
    }
}
