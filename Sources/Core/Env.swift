#if DEBUG || os(macOS)
import Foundation
import MachO
import struct os.OSAllocatedUnfairLock

public struct Env: Codable, Equatable, Sendable {
    public static let host: Env = _host.withLock { _host in
        if let _host { return _host }
        let env = Env()
        _host = env
        return env
    }
    private static let _host: OSAllocatedUnfairLock<Env?> = .init(uncheckedState: nil)

    /// /Users/username
    public var estimatedHomeDir: URL? {
        (SIMULATOR_HOST_HOME ?? NSHomeDirectory()).map(URL.init(fileURLWithPath:))
    }
    /// /Users/username/Library/Developer/Xcode/DerivedData/app-abcdefg0123456789/Build/Products/Debug-iphonesimulator
    var estimatedBuilProductsDir: [URL] {
        let a = DYLD_FRAMEWORK_PATH.filter {!$0.isEmpty}.map(URL.init(fileURLWithPath:))
        let b = [(__XPC_DYLD_FRAMEWORK_PATH ?? __XPC_DYLD_LIBRARY_PATH ?? __XCODE_BUILT_PRODUCTS_DIR_PATHS ?? __XPC_DYLD_LIBRARY_PATH ?? PWD).map(URL.init(fileURLWithPath:))].compactMap {$0}
        let c = LC_RPATHs.filter { $0.contains("/DerivedData/") && $0.contains("/Build/Products/") }.map { $0.replacingOccurrences(of: "/PackageFrameworks", with: "")
        }.map(URL.init(fileURLWithPath:))
        return a + b + c
    }
    /// /Users/username/Library/Developer/Xcode/DerivedData
    public var estimataedDerivedData: URL? {
        estimatedBuilProductsDir.map {
            URL(fileURLWithPath: $0.path.components(separatedBy: "/")
                .reversed().drop {$0 != "DerivedData"}.reversed()
                .joined(separator: "/"))
        }.first { $0.path.contains("DerivedData") }
    }
    /// app-abcdefg0123456789
    public var estimatedConfigurationBuildRandomString: String? {
        estimatedBuilProductsDir.compactMap {
            $0.path.components(separatedBy: "/")
                .drop {$0 != "DerivedData"}
                .dropFirst().first
        }.first
    }
    /// app name
    public var estimatedMainModule: String? {
        if let CFBundleExecutable { return CFBundleExecutable }
        guard let pair = estimatedConfigurationBuildRandomString?.components(separatedBy: "-"), pair.count == 2 else { return nil }
        return pair.first
    }
    /// Debug
    var estimatedConfiguration: String? {
        guard let pair = (estimatedBuilProductsDir.compactMap { $0.lastPathComponent.components(separatedBy: "-") }.first) else { return nil }
        return switch pair.count {
        case 1: pair[0]
        case 2: pair[1]
        default: nil
        }
    }
    /// Debug-ipphonesimulator
    /// Debug
    public var estimatedConfigurationPlatform: String? {
        estimatedBuilProductsDir.first?.lastPathComponent
    }
    /// iphonesimulator
    var estimatedPlatform: String? {
        DTPlatformName
    }
    /// /Applications/Xcode1501.app/Contents/Developer
    var estimatedDeveloperDir: URL? {
        (GPUTOOLS_XCODE_DEVELOPER_PATH ?? (SIMULATOR_CAPABILITIES ?? DYLD_INSERT_LIBRARIES).map {
            $0.components(separatedBy: "/")
                .reversed().drop {$0 != "Platforms"}.dropFirst().reversed()
                .joined(separator: "/")
        }).map(URL.init(fileURLWithPath:))
        ?? (self != .host ? Env.host.estimatedDeveloperDir : nil) // on iphoneos, developer dir is not available in env. use host env typically on macOS build helper
    }

    /// /Applications/Xcode1501.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator17.0.sdk
    public var estimatedSDK: URL? {
        estimatedDeveloperDir?.appendingPathComponent("Platforms")
            .appendingPathComponent(estimatedPlatformCamelCase! + ".platform")
            .appendingPathComponent("Developer/SDKs")
            .appendingPathComponent(estimatedPlatformCamelCase! + DTPlatformVersion! + ".sdk")
    }
    /// iPhoneSimulator
    var estimatedPlatformCamelCase: String? {
        guard let DTPlatformName else { return nil }
        return CFBundleSupportedPlatforms.first { $0.caseInsensitiveCompare(DTPlatformName) == .orderedSame }
    }
    var estimatedDeploymentOSVersion: String? {
        MinimumOSVersion ?? LSMinimumSystemVersion
    }
    /// arm64-apple-ios14.0-simulator
    /// arm64-apple-macos13.0
    public var estimatedTargetTriple: String? {
        let os = switch DTPlatformName {
        case "iphoneos", "iphonesimulator": "ios"
        case "macos": "macos"
        case "xros", "xrsimulator": "xros"
        default:
#if os(iOS)
            "ios"
#elseif os(macOS)
            "macos"
#elseif os(visionOS)
            "xros"
#endif
        }
        let isSimulator = DTPlatformName?.contains("simulator") == true
        return [estimatedArch, "apple", os + estimatedDeploymentOSVersion!, isSimulator ? "simulator" : nil]
            .compactMap { $0 }.joined(separator: "-")
    }
    /// arm64
    public var estimatedArch: String {
#if arch(arm64)
        "arm64"
#elseif arch(x86_64)
        "x86_64"
#endif
    }
    /// Product app bundle on host
    public var estimatedProductBundlePath: [URL] {
        guard let CFBundleName else { return [] }
        return estimatedBuilProductsDir.map { $0.appendingPathComponent(CFBundleName).appendingPathExtension("app") }
    }

    // Environment Variables
    var SIMULATOR_HOST_HOME: String?
    var DYLD_FRAMEWORK_PATH: [String]
    var DYLD_LIBRARY_PATH: [String]
    var DYLD_INSERT_LIBRARIES: String?
    var __XPC_DYLD_FRAMEWORK_PATH: String?
    var __XPC_DYLD_LIBRARY_PATH: String?
    var __XCODE_BUILT_PRODUCTS_DIR_PATHS: String?
    var GPUTOOLS_XCODE_DEVELOPER_PATH: String?
    var SIMULATOR_CAPABILITIES: String?
    var SIMULATOR_ROOT: String?
    var PWD: String?

    // Info.plist
    var DTPlatformName: String?
    var DTPlatformVersion: String?
    var DTSDKName: String?
    var CFBundleSupportedPlatforms: [String]
    var MinimumOSVersion: String?
    var LSMinimumSystemVersion: String?
    var CFBundleExecutable: String?
    var CFBundleIdentifier: String?
    var CFBundleName: String?

    // dyld
    var LC_RPATHs: [String]

    private init() {
        let env = ProcessInfo().environment
        SIMULATOR_HOST_HOME = env["SIMULATOR_HOST_HOME"]
        DYLD_FRAMEWORK_PATH = (env["DYLD_FRAMEWORK_PATH"] ?? "").components(separatedBy: ":")
        DYLD_LIBRARY_PATH = (env["DYLD_LIBRARY_PATH"] ?? "").components(separatedBy: ":")
        DYLD_INSERT_LIBRARIES = env["DYLD_INSERT_LIBRARIES"]
        __XPC_DYLD_FRAMEWORK_PATH = env["__XPC_DYLD_FRAMEWORK_PATH"]
        __XPC_DYLD_LIBRARY_PATH = env["__XPC_DYLD_LIBRARY_PATH"]
        __XCODE_BUILT_PRODUCTS_DIR_PATHS = env["__XCODE_BUILT_PRODUCTS_DIR_PATHS"]
        GPUTOOLS_XCODE_DEVELOPER_PATH = env["GPUTOOLS_XCODE_DEVELOPER_PATH"]
        SIMULATOR_CAPABILITIES = env["SIMULATOR_CAPABILITIES"]
        SIMULATOR_ROOT = env["SIMULATOR_ROOT"]
        PWD = env["PWD"]

        let info = Bundle.main.infoDictionary!
        DTPlatformName = info["DTPlatformName"] as? String
        DTPlatformVersion = info["DTPlatformVersion"] as? String
        DTSDKName = info["DTSDKName"] as? String
        CFBundleSupportedPlatforms = info["CFBundleSupportedPlatforms"] as? [String] ?? []
        MinimumOSVersion = info["MinimumOSVersion"] as? String
        LSMinimumSystemVersion = info["LSMinimumSystemVersion"] as? String
        CFBundleExecutable = info["CFBundleExecutable"] as? String
        CFBundleIdentifier = info["CFBundleIdentifier"] as? String
        CFBundleName = info["CFBundleName"] as? String

        // dyld
        LC_RPATHs = Self.LC_RPATHs
    }

    static let LC_RPATHs: [String] = (0..<_dyld_image_count()).reduce(into: []) { rpaths, i in
        guard let header = UnsafeRawPointer(_dyld_get_image_header(i))?.assumingMemoryBound(to: mach_header_64.self) else { return }
        // https://opensource.apple.com/source/xnu/xnu-2050.18.24/EXTERNAL_HEADERS/mach-o/loader.h
        // The load commands directly follow the mach_header
        let load_commands: [UnsafePointer<load_command>] = (1..<header.pointee.ncmds).reduce(into: [UnsafeRawPointer(header.advanced(by: 1)).assumingMemoryBound(to: load_command.self)]) { r, _ in
            r.append(UnsafeRawPointer(r.last!).advanced(by: Int(r.last!.pointee.cmdsize)).assumingMemoryBound(to: load_command.self))
        }
        let rpath_commands: [UnsafePointer<rpath_command>] = load_commands
            .filter { $0.pointee.cmd == LC_RPATH }
            .map { UnsafeRawPointer($0).assumingMemoryBound(to: rpath_command.self) }
        rpaths.append(contentsOf: rpath_commands.map {
            String(cString: UnsafeRawPointer($0).advanced(by: .init($0.pointee.path.offset)).assumingMemoryBound(to: CChar.self))
        })
    }
}
#endif
