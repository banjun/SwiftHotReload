//
//  ContentView.swift
//  SwiftHotReloadExample
//
//  Created by BAN Jun on 2023/10/26.
//

import SwiftUI

// see also ReplaceView.swift
struct ContentView: View {

#if DEBUG
    // these two lines are fake hook to force update of SwiftUI views
    @ObservedObject private var reloader = App.reloader
    @State private var requiredDummyState: Void = ()
#endif

    // mark `dynamic` to be replaced runtime
    // `dynamic` can be omitted if compile with `-Xfrontend -enable-implicit-dynamic`
    dynamic var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
