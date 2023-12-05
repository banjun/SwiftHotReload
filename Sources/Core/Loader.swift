#if DEBUG || os(macOS)
import Foundation

final actor Loader {
    enum Error: Swift.Error {
        case symbol_not_found_in_flat_namespace(String)
        case code_signature_invalid(String)
        case system_policy(String)
        case unknown(String)
    }

    func load(dylibPath: URL) throws {
        let handle = dlopen(dylibPath.path, RTLD_NOW)
        NSLog("%@", "🍓 dlopen handle = \(String(describing: handle))")
        guard handle != nil else {
            let error = String(cString: dlerror())
            NSLog("%@", "🍓 dlerror = \(error)")
            if error.contains("symbol not found in flat namespace") {
                NSLog("%@", "🍓 possible workarounds: remove `private` from the func, or add `-Xfrontend -enable-private-imports` to OTHER_SWIFT_FLAGS of the module to be overridden")
                throw Error.symbol_not_found_in_flat_namespace(error)
            }
            if error.contains("code signature invalid") {
                NSLog("%@", "🍓 code signature invalid: on device dylibs needs to be signed by Individual, Company or Enterprise identity (it cannot be verified by Personal identity. see `amfid` process message on the device console)")
                throw Error.code_signature_invalid(error)
            }
            if error.contains("library load disallowed by system policy") {
                NSLog("%@", "🍓 possible workarounds: turn off App Sandbox")
                throw Error.system_policy(error)
            }
            throw Error.unknown(error)
        }
    }
}

#endif
