#if DEBUG
import Foundation

struct TargetSwiftFile {
    let content: String

    var importedModules: [String] {
        content.components(separatedBy: "\n")
            .filter { $0.hasPrefix("import ") || $0.hasPrefix("@testable import ") }
            .map { $0.split(separator: " ", maxSplits: 2) }
            .filter { $0.count == 2 }
            .map { String($0[1]) }
        // FIXME: remove system modules such as Foundation
    }

    init(_ file: URL) throws {
        content = try String(contentsOf: file)
    }
}

#endif
