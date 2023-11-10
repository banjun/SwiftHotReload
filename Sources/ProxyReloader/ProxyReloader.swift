#if DEBUG
import Foundation
import MultipeerConnectivity

public final class ProxyReloader: ObservableObject {
    private let proxy: Proxy

    @Published public private(set) var dateReloaded: Date?

    public init(_ builderParams: Builder.InputParameters) {
        self.proxy = Proxy(builderParams: builderParams)

        Task {
            await proxy.$receivedDylibFiles.map {_ in Date() }.receive(on: DispatchQueue.main).assign(to: &$dateReloaded)
            await proxy.start()
        }
    }
}
#endif
