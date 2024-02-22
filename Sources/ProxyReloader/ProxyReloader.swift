#if DEBUG || os(macOS)
import Foundation
import MultipeerConnectivity

public final class ProxyReloader: ObservableObject {
    private let proxy: Proxy

    @Published public private(set) var dateReloaded: Date?

    public init(_ builderParams: Builder.InputParameters) {
        print(Env.shared)
        self.proxy = Proxy(builderParams: builderParams, shouldConnectToBuilder: UserConsent.alert)

        Task {
            await proxy.$receivedDylibFiles.map {_ in Date() }.receive(on: DispatchQueue.main).assign(to: &$dateReloaded)
            await proxy.start()
        }
    }

    public func setShouldConnectToBuilder(_ shouldConnectToBuilder: @escaping (String, String) async -> Bool) {
        Task { await proxy.setShouldConnectToBuilder(shouldConnectToBuilder) }
    }
}
#endif
