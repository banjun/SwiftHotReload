#if DEBUG || os(macOS)
import Foundation

struct NSTaskCommand {
    var launchPath: String
    var args: [String]

    enum Error: Swift.Error {
        case nsTaskUnavailable
        case failureStatus(status: Int?, stdout: String?, stderr: String?)
    }

    @discardableResult
    func run(clearEnvironments: Bool = true, setEnvHome: String? = NSHomeDirectory()) throws -> (stdout: String?, stderr: String?) {
        let NSTask: AnyClass? = NSClassFromString("NSTask")
        let task = NSTask?.value(forKey: "new") as? NSObject
        guard let task else { throw Error.nsTaskUnavailable }

        var environment = task.value(forKey: "environment") as? [AnyHashable: Any] ?? [:]
        if clearEnvironments {
            environment.removeAll()
        }
        if let setEnvHome {
            // preserve or add HOME to avoid error: `LLVM ERROR: cannot get default cache directory`
            environment["HOME"] = setEnvHome
        }
        task.setValue(environment, forKey: "environment")

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
