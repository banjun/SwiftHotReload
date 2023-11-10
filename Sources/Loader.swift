#if DEBUG
import Foundation

final actor Loader {
    enum Error: Swift.Error {
        case symbol_not_found_in_flat_namespace(String)
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
            throw Error.unknown(error)
        }
    }
}

#endif
