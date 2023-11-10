#if DEBUG
import Foundation

struct NSTaskCommand {
    var launchPath: String
    var args: [String]

    enum Error: Swift.Error {
        case nsTaskUnavailable
        case failureStatus(Int?)
    }

    func run(clearEnvironments: Bool = true) throws {
        let NSTask: AnyClass? = NSClassFromString("NSTask")
        let task = NSTask?.value(forKey: "new") as? NSObject
        guard let task else { throw Error.nsTaskUnavailable }

        if clearEnvironments {
            task.setValue([:], forKey: "environment")
        }

        task.setValue(launchPath, forKey: "launchPath")
        task.setValue(args, forKey: "arguments")

        task.value(forKey: "launch")
        task.value(forKey: "waitUntilExit")

        let terminationStatus = task.value(forKey: "terminationStatus") as? Int
        guard terminationStatus == 0 else { throw Error.failureStatus(terminationStatus) }
    }
}
#endif
