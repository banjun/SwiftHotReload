import SwiftUI
import SwiftHotReload

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

#Preview {
    ContentView()
        .environmentObject(BuildHelper())
}
