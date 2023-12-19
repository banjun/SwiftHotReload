#if DEBUG || os(macOS)
import Foundation
import Combine

public final class StandaloneReloader: ObservableObject {
    private let fileMonitor: FileMonitor
    private let core: Core?

    @Published public private(set) var dateReloaded: Date?
    private var cancellables: Set<AnyCancellable> = []

    public init(monitoredSwiftFile: URL, env: Env = .shared, derivedData: URL? = nil, confBuildDirAppRandomString: String? = nil, mainModule: String? = nil, modules: [String] = [], configurationPlatform: String? = nil, arch: String? = nil, targetTriple: String? = nil, sdk: URL? = nil, platformName: String? = nil) {
        if env.DTPlatformName == "iphoneos" {
            NSLog("%@", "🍓 ⚠️ To do hot reloads standalone, the process host should be able to execute swiftc. ⚠️")
        }

        fileMonitor = .init(file: monitoredSwiftFile)
        do {
            let builder = try Builder(.init(targetSwiftFile: monitoredSwiftFile, env: env, derivedData: derivedData, confBuildDirAppRandomString: confBuildDirAppRandomString, mainModule: mainModule, modules: modules, configurationPlatform: configurationPlatform, arch: arch, targetTriple: targetTriple, sdk: sdk, platformName: platformName))
            core = .init(builder: builder, loader: .init())
        } catch {
            NSLog("%@", "🍓 ⚠️ Cannot infer build environments. hot reloads are disabled.: \(String(describing: error)) ⚠️")
            core = nil
        }

        Task {
            await fileMonitor.$fileChanges.compactMap {$0}.sink { [weak self] _ in
                self?.reload()
            }.store(in: &cancellables)
        }
    }

    public actor Core {
        private var counter: Int = 0

        private let builder: Builder
        private let loader: Loader

        init(builder: Builder, loader: Loader) {
            self.builder = builder
            self.loader = loader
        }

        func reload() async throws {
            counter += 1

            let dylibPath = try await builder.build(dylibFilename: "HotReload\(counter).dylib")
            try await loader.load(dylibPath: dylibPath)
        }
    }

    public func reload() {
        Task { @MainActor in
            try await core?.reload()
            dateReloaded = Date()
        }
    }
}

#endif
