#if DEBUG
import Foundation

final actor Builder {
    private let targetSwiftFile: URL
    private let derivedData: URL
    private let moduleCachePath: URL
    private let confBuildDir: URL
    private let headerSearchPaths: [URL]
    private let headerMaps: [URL]
    private let buildDir: URL
    private let targetTriple: String
    private let sdk: URL
    private let arch: String
    private let platformName: String

    enum Error: Swift.Error {
        case cannotBuildOnRuntime(String?)
        case noSuchFile(URL)
        case swiftcFailure(Int?)
    }

    init(targetSwiftFile: URL, env: Env = .shared, derivedData: URL? = nil, confBuildDirAppRandomString: String? = nil, mainModule: String? = nil, modules: [String] = [], configurationPlatform: String? = nil, arch: String? = nil, targetTriple: String? = nil, sdk: URL? = nil, platformName: String? = nil) {
        self.targetSwiftFile = targetSwiftFile
        let derivedData = derivedData ?? env.estimataedDerivedData!
        self.derivedData = derivedData
        self.moduleCachePath = derivedData.appendingPathComponent("ModuleCache.noindex")
        let confBuildDirAppRandomString = confBuildDirAppRandomString ?? env.estimatedConfigurationBuildRandomString!
        let mainModule = mainModule ?? env.estimatedMainModule!
        let intermediatesDir = derivedData
            .appendingPathComponent(confBuildDirAppRandomString)
            .appendingPathComponent("Build/Intermediates.noindex")
        let configurationPlatform = configurationPlatform ?? env.estimatedConfigurationPlatform!
        let confBuildDir = intermediatesDir
            .appendingPathComponent(mainModule + ".build")
            .appendingPathComponent(configurationPlatform)
        self.confBuildDir = confBuildDir
        let arch = arch ?? env.estimatedArch
        self.arch = arch
        self.headerSearchPaths = ([mainModule] + modules).map {
            confBuildDir
                .appendingPathComponent($0 + ".build")
                .appendingPathComponent("Objects-normal")
                .appendingPathComponent(arch)
        }
        self.headerMaps = [confBuildDir
            .appendingPathComponent(mainModule + ".build")
            .appendingPathComponent("\(mainModule)-project-headers.hmap")
        ] + [intermediatesDir
            .appendingPathComponent("Pods" + ".build")
            .appendingPathComponent(configurationPlatform)
            .appendingPathComponent("Pods-\(mainModule)" + ".build")
            .appendingPathComponent("Pods_\(mainModule)-project-headers.hmap")
        ]
        self.buildDir = headerSearchPaths.first!
        self.targetTriple = targetTriple ?? env.estimatedTargetTriple!
        self.sdk = sdk ?? env.estimatedSDK!
        self.platformName = platformName ?? env.DTPlatformName!
    }

    func build(dylibFilename: String) throws -> URL {
        let dylibPath = buildDir.appendingPathComponent(dylibFilename)
        try build(dylibPath: dylibPath)
        return dylibPath
    }

    func build(dylibPath: URL) throws {
        guard platformName != "iphoneos" else {
            NSLog("%@", "🍓 ⚠️ To do hot reloads, the process host should be able to execute swiftc. cancelled building the target swift file. ⚠️")
            throw Error.cannotBuildOnRuntime(platformName)
        }

        guard let file = try? TargetSwiftFile(targetSwiftFile) else { throw Error.noSuchFile(targetSwiftFile) }
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
            ["-Xlinker", "-flat_namespace"], // for Xcode 14 (unneeded for Xcode 15)
            (headerSearchPaths + importedModuleSearchPaths).flatMap { ["-I", $0.path] },
            headerMaps.flatMap { ["-Xcc", "-I", "-Xcc", $0.path] }
        ].flatMap { $0 }
        task.setValue(args, forKey: "arguments")
        NSLog("%@", "🍓 exec and args = ")
        print("\(launchPath) \(args.joined(separator: " "))")
        task.value(forKey: "launch")
        task.value(forKey: "waitUntilExit")

        let terminationStatus = task.value(forKey: "terminationStatus") as? Int
        // NSLog("%@", "🍓 terminationStatus = \(String(describing: terminationStatus))")
        guard terminationStatus == 0 else { throw Error.swiftcFailure(terminationStatus) }
    }
}

#endif
