#if os(macOS)
// NOTE: should not be submitted for App Store Review
// Release build is not disabled as BuildHelper.app is to be buildable for generating a mac helper app.
// TODO: BuildHelper may be separated into sub- spec/package
import Foundation
import MultipeerConnectivity
@testable import SwiftHotReload // NOTE: use internal methods. SPM does not allow overlapping sources for a single Package.swift

final actor ProxyBrowser {
    @Published private(set) var runtimePeers: [RuntimePeer] = []
    private let peerID: MCPeerID
    private let session: MCSession
    private let browser: MCNearbyServiceBrowser
    private let sessionDelegate: SessionDelegate = .init()
    let browserView: MCBrowserViewControllerView

    init(hostName: String = ProcessInfo().hostName, bundleID: String? = Env.shared.CFBundleIdentifier, processID: Int32 = ProcessInfo().processIdentifier) {
        let displayName = String("Client[\(hostName)] \(bundleID ?? "cli")(\(processID))".utf8.prefix(63))!
        self.peerID = MCPeerID(displayName: displayName)
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: MultipeerConnectivityConstants.serviceType)
        self.browserView = MCBrowserViewControllerView(browser: browser, session: session)

//        Task {
            session.delegate = sessionDelegate
            sessionDelegate.owner = self
//        }
    }

    func start() {
        NSLog("%@", "🍓 ProxyBrowser.\(#function)")
        browser.startBrowsingForPeers()
    }

    func stop() {
        NSLog("%@", "🍓 ProxyBrowser.\(#function)")
        browser.stopBrowsingForPeers()
    }

    // MARK: - MCSessionDelegate

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .notConnected:
            NSLog("%@", "🍓 \(#function) .notConnected: peerID = \(peerID)")
            runtimePeers = runtimePeers.filter { $0.peerID != peerID }
        case .connecting:
            NSLog("%@", "🍓 \(#function) .connecting: peerID = \(peerID)")
        case .connected:
            NSLog("%@", "🍓 \(#function) .connected: peerID = \(peerID)")
            // NOTE: it is a good idea doing some auth to refrain from sending secret dylib to the unidentified server
            runtimePeers.append(.init(session: session, peerID: peerID, builderParams: nil))
        @unknown default:
            NSLog("%@", "🍓 \(#function) @unknown default: peerID = \(peerID)")
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        NSLog("%@", "🍓 \(#function) data = \(data.count) bytes, peerID = \(peerID)")
        do {
            let builderParams = try JSONDecoder().decode(Builder.InputParameters.self, from: data)
            NSLog("%@", "🍓 \(#function) using received build parameters when build for the session: \(builderParams)")
            guard let index = (runtimePeers.firstIndex { $0.peerID == peerID }) else { return }
            runtimePeers[index].builderParams = builderParams
        } catch {
            NSLog("%@", "🍓 \(#function) error = \(error)")
        }
    }
}

private extension ProxyBrowser {
    private final class SessionDelegate: NSObject, MCSessionDelegate {
        unowned var owner: ProxyBrowser?
        override init() { super.init() }

        func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
            Task { await owner?.session(session, peer: peerID, didChange: state) }
        }

        func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
            Task { await owner?.session(session, didReceive: data, fromPeer: peerID) }
        }

        func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
            NSLog("%@", "🍓 \(#function) stream = \(stream), streamName = \(streamName), peerID = \(peerID)")
        }

        func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
            NSLog("%@", "🍓 \(#function) resourceName = \(resourceName), peerID = \(peerID), progress = \(progress)")
        }

        func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Swift.Error?) {
            NSLog("%@", "🍓 \(#function) resourceName = \(resourceName), peerID = \(peerID), localURL = \(String(describing: localURL)), error = \(String(describing: error))")
        }
    }
}
#endif
