#if DEBUG || os(macOS)
import Foundation

final actor FileMonitor {
    private let file: URL
    @Published private(set) var fileChanges: Date?

    private var monitor: DispatchSourceFileSystemObject? {
        didSet {
            oldValue?.cancel()
            if let monitor {
                monitor.resume()
            }
        }
    }

    private var lastTargetFileContent: String?

    init(file: URL) {
        self.file = file

        guard Env.shared.DTPlatformName != "iphoneos" else {
            NSLog("%@", "🍓 ⚠️ To do hot reloads, the process host should be able to execute swiftc. cancelled installing the file monitor. ⚠️")
            return
        }

        Task {
            await install()
        }
    }

    private func install() {
        NSLog("%@", "🍓 \(#function) starting file monitor for file at \(file.path)")
        let handle = FileHandle(forReadingAtPath: file.path)
        monitor = handle.map { DispatchSource.makeFileSystemObjectSource(fileDescriptor: $0.fileDescriptor, eventMask: .all) }
        monitor?.setEventHandler { [unowned self] in
            let content = try? TargetSwiftFile(file).content
            guard content != lastTargetFileContent else {
                // NSLog("%@", "🍓 target file change detected but same content. ignored.")
                return
            }
            NSLog("%@", "🍓 target file change detected")
            lastTargetFileContent = content
            fileChanges = Date()

            self.monitor = nil
            handle?.closeFile()
            self.install()
        }
    }
}

#endif
