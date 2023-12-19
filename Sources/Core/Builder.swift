#if DEBUG || os(macOS)
import Foundation

public final actor Builder {
    private let targetSwiftFile: URL
    private let derivedData: URL
    private let moduleCachePath: URL
    private let confBuildDir: URL
    private let headerSearchPaths: [URL]
    private let headerMaps: [URL]
    private let buildDir: URL
    private let targetTriple: String
    private let sdk: URL?
    private let arch: String
    private let platformName: String
    private let codesignIdentity: String?

    public struct InputParameters: Codable {
        public var targetSwiftFile: URL
        public var env: Env
        public var derivedData: URL?
        public var confBuildDirAppRandomString: String?
        public var mainModule: String?
        public var modules: [String] = []
        public var configurationPlatform: String?
        public var arch: String?
        public var targetTriple: String?
        public var sdk: URL?
        public var platformName: String?
        public var codesignIdentity: String?

        public init(targetSwiftFile: URL, env: Env = .shared, derivedData: URL? = nil, confBuildDirAppRandomString: String? = nil, mainModule: String? = nil, modules: [String] = [], configurationPlatform: String? = nil, arch: String? = nil, targetTriple: String? = nil, sdk: URL? = nil, platformName: String? = nil, codesignIdentity: String? = nil) {
            self.targetSwiftFile = targetSwiftFile
            self.env = env
            self.derivedData = derivedData
            self.confBuildDirAppRandomString = confBuildDirAppRandomString
            self.mainModule = mainModule
            self.modules = modules
            self.configurationPlatform = configurationPlatform
            self.arch = arch
            self.targetTriple = targetTriple
            self.sdk = sdk
            self.platformName = platformName
            self.codesignIdentity = codesignIdentity
        }
    }

    enum Error: Swift.Error {
        case missingRequiredEnvironments(String?)
        case cannotBuildOnRuntime(String?)
        case noSuchFile(URL)
        case swiftcFailure(Int?)
    }

    init(_ p: InputParameters) throws {
        self.targetSwiftFile = p.targetSwiftFile
        guard let derivedData = p.derivedData ?? p.env.estimataedDerivedData else {
            throw Error.missingRequiredEnvironments("derivedData")
        }
        self.derivedData = derivedData
        self.moduleCachePath = derivedData.appendingPathComponent("ModuleCache.noindex")
        guard let confBuildDirAppRandomString = p.confBuildDirAppRandomString ?? p.env.estimatedConfigurationBuildRandomString else {
            throw Error.missingRequiredEnvironments("confBuildDirAppRandomString")
        }
        guard let mainModule = p.mainModule ?? p.env.estimatedMainModule else {
            throw Error.missingRequiredEnvironments("mainModule")
        }
        let intermediatesDir = derivedData
            .appendingPathComponent(confBuildDirAppRandomString)
            .appendingPathComponent("Build/Intermediates.noindex")
        guard let configurationPlatform = p.configurationPlatform ?? p.env.estimatedConfigurationPlatform else {
            throw Error.missingRequiredEnvironments("configurationPlatform")
        }
        let confBuildDir = intermediatesDir
            .appendingPathComponent(mainModule + ".build")
            .appendingPathComponent(configurationPlatform)
        self.confBuildDir = confBuildDir
        let arch = p.arch ?? p.env.estimatedArch
        self.arch = arch
        self.headerSearchPaths = ([mainModule] + p.modules).map {
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
        guard let buildDir = headerSearchPaths.first else {
            throw Error.missingRequiredEnvironments("buildDir")
        }
        self.buildDir = buildDir
        self.targetTriple = p.targetTriple ?? p.env.estimatedTargetTriple!
        self.sdk = p.sdk ?? p.env.estimatedSDK ?? Env.shared.estimatedSDK
        self.platformName = p.platformName ?? p.env.DTPlatformName!
        self.codesignIdentity = p.codesignIdentity
    }

    func build(dylibFilename: String) throws -> URL {
        let dylibPath = buildDir.appendingPathComponent(dylibFilename)
        try build(dylibPath: dylibPath)
        if let codesignIdentity {
            try codesign(dylibPath: dylibPath, codesignIdentity: codesignIdentity)
        }
        return dylibPath
    }

    func build(dylibPath: URL) throws {
        guard Env.shared.DTPlatformName != "iphoneos" else {
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

        let command = NSTaskCommand(
            launchPath: "/usr/bin/xcrun",
            args: [
                ["--sdk", platformName], // `xcrun --sdk iphoneos swiftc ...` to suppress `clang: warning: using sysroot for 'MacOSX' but targeting 'iPhone' [-Wincompatible-sysroot]` and to set correct VersionSDK for codesign
                ["/usr/bin/swiftc"],
                ["-emit-library"], // generates dylib
                [targetSwiftFile.path],
                ["-o", dylibPath.path],
                sdk.flatMap { ["-sdk", $0.path] } ?? [],
                ["-target", targetTriple],
                ["-module-cache-path", moduleCachePath.path], // required in some cases
                ["-Xlinker", "-undefined", "-Xlinker", "suppress"], // avoid fatal error on the linker
                ["-Xfrontend", "-disable-access-control"], // with this, internal symbols can be used
                ["-Xlinker", "-flat_namespace"], // for Xcode 14 (unneeded for Xcode 15)
                (headerSearchPaths + importedModuleSearchPaths).flatMap { ["-I", $0.path] },
                headerMaps.flatMap { ["-Xcc", "-I", "-Xcc", $0.path] }
            ].flatMap { $0 })

        NSLog("%@", "🍓 build: exec and args = ")
        print("\(command.launchPath) \(command.args.joined(separator: " "))")
        
        try command.run()
    }

    /// codesign the dylib
    ///
    /// in case error message on a runtime device  on dlopen:
    /// > .dylib' not valid for use in process: mapped file has no cdhash, completely unsigned? Code has to be at least ad-hoc signed.
    ///
    /// ad-hoc sign is not valid for devices
    func codesign(dylibPath: URL, codesignIdentity: String) throws {
        let command = NSTaskCommand(launchPath: "/usr/bin/codesign", args: [
            "-f", "-s", codesignIdentity, dylibPath.path
        ])
        NSLog("%@", "🍓 codesign: exec and args = ")
        print("\(command.launchPath) \(command.args.joined(separator: " "))")
        let outputs = try command.run()
        print(outputs)
    }
}

#endif
