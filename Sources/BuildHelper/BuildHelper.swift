#if os(macOS)
// NOTE: should not be submitted for App Store Review
// Release build is not disabled as BuildHelper.app is to be buildable for generating a mac helper app.
// TODO: BuildHelper may be separated into sub- spec/package
import Foundation
import Combine

public final class BuildHelper: ObservableObject {
    private let proxyBrowser = ProxyBrowser()

    @Published public private(set) var monitoredFile: URL? {
        didSet {
            fileMonitor = monitoredFile.map { FileMonitor(file: $0) }
        }
    }
    private var fileMonitor: FileMonitor? {
        didSet {
            Task {
                fileMonitorCancellable = await fileMonitor?.$fileChanges.compactMap {$0}.sink { [weak self] _ in
                    self?.reload()
                }
            }
        }
    }
    private var fileMonitorCancellable: AnyCancellable?
    private let core = Core()

    @Published public private(set) var dateReloaded: Date?
    private var cancellables: Set<AnyCancellable> = []

    public init() {
        Task { @MainActor in
            await proxyBrowser.$runtimePeer.receive(on: DispatchQueue.main).sink { [weak self] runtimePeer in
                guard let self else { return }
                monitoredFile = runtimePeer?.builderParams?.targetSwiftFile
                Task { await self.core.setRuntimePeer(runtimePeer) }
            }.store(in: &cancellables)
        }
    }

    private actor Core {
        private var counter: Int = 0

        private var builder: Builder?
        private var runtimePeer: RuntimePeer? {
            didSet {
                self.builder = runtimePeer?.builderParams.map(Builder.init)
            }
        }

        enum Error: Swift.Error {
            case builderUninitialized
        }

        init() {}

        func setRuntimePeer(_ runtimePeer: RuntimePeer?) {
            self.runtimePeer = runtimePeer
        }

        func reload() async throws {
            guard let builder else { throw Error.builderUninitialized }
            counter += 1

            let dylibPath = try await builder.build(dylibFilename: "HotReload\(counter).dylib", codesignIdentity: "Apple Development: ..... ..... (..........)") // FIXME: hardcoded identity
            guard let session = runtimePeer?.session, let server = runtimePeer?.peerID else { return }
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Swift.Error>) in
                session.sendResource(at: dylibPath, withName: dylibPath.lastPathComponent, toPeer: server) { error in
                    if let error { c.resume(throwing: error) }
                    else { c.resume() }
                }
            }
        }
    }

    public func reload() {
        Task { @MainActor in
            try await core.reload()
            dateReloaded = Date()
        }
    }
}
#endif
