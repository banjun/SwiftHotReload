import SwiftUI
import SwiftHotReload

// NOTE: for mac target, disable sandbox in the entitlement file

@main
struct App: SwiftUI.App {
#if DEBUG
    // For Simulators and macOS apps:
    // just use StandaloneReloader
    //
    // For iPhone devices:
    // use ProxyReloader while running BuildHelper.app on the host Mac
    //
    // See also `ReplaceView.swift`
    //
    // ↓ Change true/false to switch StandaloneReloader or ProxyReloader
#if true
    // StandaloneReloader
    static let reloader = StandaloneReloader(monitoredSwiftFile: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("ReplaceView.swift")
    )
#else
    // ProxyReloader
    static let reloader = ProxyReloader(.init(targetSwiftFile: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("ReplaceView.swift")
    ))
#endif
#endif
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
