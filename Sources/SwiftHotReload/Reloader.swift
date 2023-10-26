#if DEBUG
import Foundation

public final class Reloader: ObservableObject {
    public static var shared: Reloader?

    @Published public private(set) var dateReloaded: Date?

    private let core: Core
    public actor Core {
        private var counter: Int = 0

        let targetSwiftFile: URL
        private let derivedData: URL
        private let moduleCachePath: URL
        private let confBuildDir: URL
        private let headerSearchPaths: [URL]
        private let buildDir: URL
        private let targetTriple: String
        private let sdk: URL
        private let arch: String

        init(derivedData: URL = Env.shared.estimataedDerivedData!, targetSwiftFile: URL, confBuildDirAppRandomString: String = Env.shared.estimatedConfigurationBuildRandomString!, mainModule: String = Env.shared.estimatedMainModule!, modules: [String] = [], configurationPlatform: String = Env.shared.estimatedConfigurationPlatform!, arch: String = Env.shared.estimatedArch, targetTriple: String = Env.shared.estimatedTargetTriple!, sdk: URL = Env.shared.estimatedSDK!) {
            self.targetSwiftFile = targetSwiftFile
            self.derivedData = derivedData
            self.moduleCachePath = derivedData.appendingPathComponent("ModuleCache.noindex")
            let confBuildDir = derivedData
                .appendingPathComponent(confBuildDirAppRandomString)
                .appendingPathComponent("Build/Intermediates.noindex")
                .appendingPathComponent(mainModule + ".build")
                .appendingPathComponent(configurationPlatform)
            self.confBuildDir = confBuildDir
            self.headerSearchPaths = ([mainModule] + modules).map {
                confBuildDir
                    .appendingPathComponent($0 + ".build")
                    .appendingPathComponent("Objects-normal")
                    .appendingPathComponent(arch)
            }
            self.buildDir = headerSearchPaths.first!
            self.targetTriple = targetTriple
            self.sdk = sdk
            self.arch = arch
        }

        func reload() -> Bool {
            counter += 1

            let dylibPath = buildDir.appendingPathComponent("HotReload\(counter).dylib")
            return build(dylibPath: dylibPath)
            && load(dylibPath: dylibPath)
        }

        private func build(dylibPath: URL) -> Bool {
            guard Env.shared.DTPlatformName != "iphoneos" else {
                NSLog("%@", "🍓 ⚠️ To do hot reloads, the process host should be able to execute swiftc. cancelled building the target swift file. ⚠️")
                return false
            }

            guard let file = try? TargetSwiftFile(targetSwiftFile) else { return false }
            let importedModuleSearchPaths = file.importedModules.map {
                confBuildDir
                    .appendingPathComponent($0 + ".build")
                    .appendingPathComponent("Objects-normal")
                    .appendingPathComponent(arch)
            }

            let NSTask: AnyClass = NSClassFromString("NSTask")!
            //        NSLog("%@", "🍓 NSTask = \(NSTask)")
            let task = NSTask.value(forKey: "new")! as! NSObject
            //        NSLog("%@", "🍓 task = \(task)")
            task.setValue([:], forKey: "environment")
            let launchPath = "/usr/bin/swiftc"
            task.setValue(launchPath, forKey: "launchPath")
            let args: [String] = [
                ["-emit-library"], // generates dylib
                [targetSwiftFile.path],
                ["-o", dylibPath.path],
                ["-sdk", sdk.path],
                ["-target", targetTriple],
                ["-module-cache-path", moduleCachePath.path], // required in some cases
                ["-Xlinker", "-undefined", "-Xlinker", "suppress"], // avoid fatal error on the linker
                ["-Xfrontend", "-disable-access-control"], // with this, internal symbols can be used
                (headerSearchPaths + importedModuleSearchPaths).flatMap { ["-I", $0.path] }
            ].flatMap { $0 }
            task.setValue(args, forKey: "arguments")
            NSLog("%@", "🍓 exec and args = ")
            print("\(launchPath) \(args.joined(separator: " "))")
            task.value(forKey: "launch")
            task.value(forKey: "waitUntilExit")

            let terminationStatus = task.value(forKey: "terminationStatus") as? Int
            // NSLog("%@", "🍓 terminationStatus = \(String(describing: terminationStatus))")
            return terminationStatus == 0
        }

        private func load(dylibPath: URL) -> Bool {
            let handle = dlopen(dylibPath.path, RTLD_NOW)
            NSLog("%@", "🍓 dlopen handle = \(String(describing: handle))")
            return handle != nil
        }
    }

    public init(_ core: Core) {
        self.core = core
    }

    private var monitor: DispatchSourceFileSystemObject? {
        didSet {
            oldValue?.cancel()
            if let monitor {
                monitor.resume()
            }
        }
    }

    private var lastTargetFileContent: String?

    public func install() {
        guard Env.shared.DTPlatformName != "iphoneos" else {
            NSLog("%@", "🍓 ⚠️ To do hot reloads, the process host should be able to execute swiftc. cancelled installing the file monitor. ⚠️")
            return
        }

        let handle = FileHandle(forReadingAtPath: core.targetSwiftFile.path)
        monitor = handle.map { DispatchSource.makeFileSystemObjectSource(fileDescriptor: $0.fileDescriptor, eventMask: .all) }
        monitor?.setEventHandler { [unowned self] in
            let content = try? TargetSwiftFile(core.targetSwiftFile).content
            guard content != lastTargetFileContent else {
                // NSLog("%@", "🍓 target file change detected but same content. ignored.")
                return
            }
            NSLog("%@", "🍓 target file change detected")
            lastTargetFileContent = content
            self.reload()

            self.monitor = nil
            handle?.closeFile()
            self.install()
        }
    }

    public func reload() {
        Task { @MainActor in
            if await core.reload() {
                dateReloaded = Date()
            }
        }
    }
}
#endif
