#if DEBUG || os(macOS)
import Foundation
@preconcurrency import Combine

final actor FileMonitor {
    private let file: URL
    private let fileChangesSubject: CurrentValueSubject<Date?, Never> = .init(nil)
    var fileChanges: AnyPublisher<Date?, Never> { fileChangesSubject.eraseToAnyPublisher() }

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

        guard Env.host.DTPlatformName != "iphoneos" else {
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
        monitor?.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await targetFileChangeDetected(handle) }
        }
    }

    private func targetFileChangeDetected(_ handle: FileHandle?) {
        let content = try? TargetSwiftFile(file).content
        guard content != lastTargetFileContent else {
            // NSLog("%@", "🍓 target file change detected but same content. ignored.")
            return
        }
        NSLog("%@", "🍓 target file change detected")
        lastTargetFileContent = content
        Task { @MainActor in
            await fileChangesSubject.send(Date())
        }

        monitor = nil
        handle?.closeFile()
        install()
    }
}

#endif
