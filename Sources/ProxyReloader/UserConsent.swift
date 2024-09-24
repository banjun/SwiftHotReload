import Foundation

enum UserConsent {
}

#if canImport(AppKit)
import AppKit
extension UserConsent {
    @MainActor
    static func alert(_ title: String, _ message: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "Trust").hasDestructiveAction = true
            alert.addButton(withTitle: "Cancel")

            continuation.resume(returning: alert.runModal() == .alertFirstButtonReturn)
        }
    }
}

#elseif canImport(UIKit)
import UIKit
extension UserConsent {
    @MainActor
    static func alert(_ title: String, _ message: String) async -> Bool {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
#if os(visionOS)
            .filter { $0.session.role != .immersiveSpaceApplication }
#endif
        guard let window = (windowScenes.compactMap { $0.windows.first { $0.isKeyWindow } }.first) else {
            NSLog("%@", "⚠️ cannot get keyWindow from scenes = \(UIApplication.shared.connectedScenes)")
            return false
        }

        var vc = window.rootViewController
        while let pvc = vc?.presentedViewController {
            vc = pvc
        }

        return await withCheckedContinuation { continuation in
            let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
            ac.addAction(.init(title: "Trust", style: .destructive) {_ in continuation.resume(returning: true) })
            ac.addAction(.init(title: "Cancel", style: .cancel) {_ in continuation.resume(returning: false) })
            vc?.present(ac, animated: true)
        }
    }
}
#endif
