#if DEBUG
import Foundation

struct NSTaskCommand {
    var launchPath: String
    var args: [String]

    enum Error: Swift.Error {
        case nsTaskUnavailable
        case failureStatus(status: Int?, stdout: String?, stderr: String?)
    }

    @discardableResult
    func run(clearEnvironments: Bool = true) throws -> (stdout: String?, stderr: String?) {
        let NSTask: AnyClass? = NSClassFromString("NSTask")
        let task = NSTask?.value(forKey: "new") as? NSObject
        guard let task else { throw Error.nsTaskUnavailable }

        if clearEnvironments {
            task.setValue([:], forKey: "environment")
        }

        task.setValue(launchPath, forKey: "launchPath")
        task.setValue(args, forKey: "arguments")

        let stdout = Pipe()
        let stderr = Pipe()
        task.setValue(stdout, forKey: "standardOutput")
        task.setValue(stderr, forKey: "standardError")

        task.value(forKey: "launch")
        task.value(forKey: "waitUntilExit")

        let outputs = (
            stdout: (try? stdout.fileHandleForReading.readToEnd()).flatMap { String(data: $0, encoding: .utf8) },
            stderr: (try? stderr.fileHandleForReading.readToEnd()).flatMap { String(data: $0, encoding: .utf8) })

        let terminationStatus = task.value(forKey: "terminationStatus") as? Int
        guard terminationStatus == 0 else { throw Error.failureStatus(status: terminationStatus, stdout: outputs.stdout, stderr: outputs.stderr) }

        return outputs
    }
}
#endif
