//
//  SwiftHotReloadExampleApp.swift
//  SwiftHotReloadExample
//
//  Created by BAN Jun on 2023/10/26.
//

import SwiftUI
import SwiftHotReload

// NOTE: for mac target, disable sandbox in the entitlement file

@main
struct App: SwiftUI.App {

#if DEBUG
    // see also ReplaceView.swift
    static let reloader = StandaloneReloader(monitoredSwiftFile: Env.shared.estimatedHomeDir!
            .appendingPathComponent("projects/github/SwiftHotReload")
            .appendingPathComponent("Example/ReplaceView.swift")
    )
#endif
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
