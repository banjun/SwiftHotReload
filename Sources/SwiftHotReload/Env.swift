#if DEBUG
import Foundation

struct Env {
    static let shared: Env = .init()

    /// /Users/username
    var estimatedHomeDir: URL? {
        SIMULATOR_HOST_HOME.map(URL.init(fileURLWithPath:))
    }
    /// /Users/username/Library/Developer/Xcode/DerivedData/app-abcdefg0123456789/Build/Products/Debug-iphonesimulator
    var estimatedBuilProductsDir: URL? {
        (DYLD_FRAMEWORK_PATH ?? __XPC_DYLD_FRAMEWORK_PATH ?? __XPC_DYLD_LIBRARY_PATH ?? __XCODE_BUILT_PRODUCTS_DIR_PATHS ?? __XPC_DYLD_LIBRARY_PATH ?? PWD).map(URL.init(fileURLWithPath:))
    }
    /// /Users/username/Library/Developer/Xcode/DerivedData
    var estimataedDerivedData: URL? {
        estimatedBuilProductsDir.map {
            URL(fileURLWithPath: $0.path.components(separatedBy: "/")
                .reversed().drop {$0 != "DerivedData"}.reversed()
                .joined(separator: "/"))
        }
    }
    /// app-abcdefg0123456789
    var estimatedConfigurationBuildRandomString: String? {
        (estimatedBuilProductsDir?.path ?? "").components(separatedBy: "/")
            .drop {$0 != "DerivedData"}
            .dropFirst().first
    }
    /// app name
    var estimatedMainModule: String? {
        guard let pair = estimatedConfigurationBuildRandomString?.components(separatedBy: "-"), pair.count == 2 else { return nil }
        return pair.first
    }
    /// Debug
    var estimatedConfiguration: String? {
        guard let pair = estimatedBuilProductsDir?.lastPathComponent.components(separatedBy: "-") else { return nil }
        return switch pair.count {
        case 1: pair[0]
        case 2: pair[1]
        default: nil
        }
    }
    /// Debug-ipphonesimulator
    /// Debug
    var estimatedConfigurationPlatform: String? {
        estimatedBuilProductsDir?.lastPathComponent
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
    }
    /// /Applications/Xcode1501.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator17.0.sdk
    var estimatedSDK: URL? {
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
    var estimatedTargetTriple: String? {
        guard let os = (DTPlatformName?.contains("iphone") == true ? "ios"
                        : DTPlatformName?.contains("macosx") == true ? "macos"
                        : nil) else { return nil }
        let isSimulator = DTPlatformName?.contains("simulator") == true
        return [estimatedArch, "apple", os + estimatedDeploymentOSVersion!, isSimulator ? "simulator" : nil]
            .compactMap { $0 }.joined(separator: "-")
    }
    /// arm64
    var estimatedArch: String {
#if arch(arm64)
        "arm64"
#endif
    }

    // Environment Variables
    var SIMULATOR_HOST_HOME: String?
    var DYLD_FRAMEWORK_PATH: String?
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

    private init() {
        let env = ProcessInfo().environment
        SIMULATOR_HOST_HOME = env["SIMULATOR_HOST_HOME"]
        DYLD_FRAMEWORK_PATH = env["DYLD_FRAMEWORK_PATH"]
        DYLD_LIBRARY_PATH = (env["DYLD_LIBRARY_PATH"] ?? "") .components(separatedBy: ":")
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
    }
}
#endif
