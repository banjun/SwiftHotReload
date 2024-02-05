#if os(macOS)
@testable import SwiftHotReload // NOTE: use internal methods. SPM does not allow overlapping sources for a single Package.swift
// NOTE: should not be submitted for App Store Review
// Release build is not disabled as BuildHelper.app is to be buildable for generating a mac helper app.
// TODO: BuildHelper may be separated into sub- spec/package
import Foundation
import Combine

public final class BuildHelper: ObservableObject {
    let proxyBrowser = ProxyBrowser()

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
            await proxyBrowser.$runtimePeers.receive(on: DispatchQueue.main).sink { [weak self] runtimePeers in
                guard let self else { return }
                // TODO: support multiple peers
                let runtimePeer = runtimePeers.first
                NSLog("%@", "🍓 TODO: support multiple peers: \(runtimePeers.count) peers connected. currently using only first peer \(String(describing: runtimePeer))")
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
                do {
                    self.builder = try runtimePeer?.builderParams.flatMap { try Builder($0) }
                } catch {
                    NSLog("%@", "🍓 ⚠️ Cannot infer build environments. hot reloads are disabled.: \(String(describing: error)) ⚠️")
                    self.builder = nil
                }
            }
        }

        enum Error: Swift.Error {
            case builderUninitialized
        }

        init() {}

        func setRuntimePeer(_ runtimePeer: RuntimePeer?) {
            var runtimePeer = runtimePeer
            if let p = runtimePeer?.builderParams, p.codesignIdentity == nil {
                let identity = p.env.estimatedProductBundlePath.filter { FileManager.default.fileExists(atPath: $0.path) }.lazy.compactMap {
                    let stderr = try? NSTaskCommand(launchPath: "/usr/bin/codesign", args: ["-dvvvvv", $0.path]).run().stderr
                    // extract `Apple Development: xxxxxx@xxxxxx (XXXXXXXXXX)`
                    return stderr?.components(separatedBy: "\n").first { $0.hasPrefix("Authority=") }?.split(separator: "=", maxSplits: 2).last
                }.map(String.init).first
                runtimePeer?.builderParams?.codesignIdentity = identity
            }
            self.runtimePeer = runtimePeer
        }

        func reload() async throws {
            guard let builder else { throw Error.builderUninitialized }
            counter += 1

            let dylibPath = try await builder.build(dylibFilename: "HotReload\(counter).dylib")
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
