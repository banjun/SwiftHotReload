import SwiftUI
import SwiftHotReloadExample

// step
// 1. watch this file full path at App.swift
// 2. run app target
// 3. edit & save this file

extension ContentView {
    @_dynamicReplacement(for: body)
    var body2: some View {
        Text("Replaced!!")
            .font(.largeTitle)
    }
}
