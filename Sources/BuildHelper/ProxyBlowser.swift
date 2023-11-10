#if os(macOS)
// NOTE: should not be submitted for App Store Review
// Release build is not disabled as BuildHelper.app is to be buildable for generating a mac helper app.
// TODO: BuildHelper may be separated into sub- spec/package
import Foundation
import MultipeerConnectivity

final actor ProxyBrowser {
    @Published private(set) var runtimePeer: RuntimePeer? {
        didSet {
            runtimePeer?.session.delegate = sessionDelegate
        }
    }
    private let peerID: MCPeerID
    private let browser: MCNearbyServiceBrowser
    private let browserDelegate: BrowserDelegate
    private let sessionDelegate: SessionDelegate = .init()

    init(hostName: String = ProcessInfo().hostName, bundleID: String = Env.shared.CFBundleIdentifier!, processID: Int32 = ProcessInfo().processIdentifier) {
        let displayName = String("Client[\(hostName)] \(bundleID)(\(processID))".utf8.prefix(63))!
        self.peerID = MCPeerID(displayName: displayName)
        self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: MultipeerConnectivityConstants.serviceType)
        self.browserDelegate = BrowserDelegate()

        self.browser.delegate = browserDelegate
        Task {
            browserDelegate.owner = self
            sessionDelegate.owner = self
            await start()
        }
    }

    // MARK: - MCNearbyServiceBrowserDelegate

    private final class BrowserDelegate: NSObject, MCNearbyServiceBrowserDelegate {
        unowned var owner: ProxyBrowser?
        override init() { super.init() }

        func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
            Task { await owner?.browser(browser, foundPeer: peerID, withDiscoveryInfo: info) }
        }

        func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
            Task { await owner?.browser(browser, lostPeer: peerID) }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("%@", "🍓 \(#function) peerID = \(peerID), info = \(String(describing: info))")
        guard info == MultipeerConnectivityConstants.serverDiscoveryInfo else {
            NSLog("%@", "🍓 \(#function) ignore peer \(peerID) as it's not a server")
            return
        }
        guard runtimePeer == nil else {
            NSLog("%@", "🍓 \(#function) ⚠️ TODO: support mutiple sessions")
            return
        }

        NSLog("%@", "🍓 \(#function) ⚠️ TODO: some auth to refrain from sending secret dylib to the unidentified server")
        let session = MCSession(peer: self.peerID, securityIdentity: nil, encryptionPreference: .required)
        self.browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        runtimePeer = .init(session: session, peerID: peerID, builderParams: nil)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@", "🍓 \(#function) peerID = \(peerID)")
        if runtimePeer?.peerID == peerID {
            runtimePeer = nil
        }
    }

    // MARK: - MCSessionDelegate

    private final class SessionDelegate: NSObject, MCSessionDelegate {
        unowned var owner: ProxyBrowser?
        override init() { super.init() }

        func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
            NSLog("%@", "🍓 \(#function) peerID = \(peerID), state = \(state)")
        }

        func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
            NSLog("%@", "🍓 \(#function) data = \(data.count) bytes, peerID = \(peerID)")
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

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let builderParams = try JSONDecoder().decode(Builder.InputParameters.self, from: data)
            NSLog("%@", "🍓 \(#function) using received build parameters when build for the session: \(builderParams)")
            var runtimePeer = runtimePeer
            runtimePeer?.builderParams = builderParams
            self.runtimePeer = runtimePeer
        } catch {
            NSLog("%@", "🍓 \(#function) error = \(error)")
        }
    }

    // MARK: -

    func start() {
        browser.startBrowsingForPeers()
    }

    func stop() {
        browser.stopBrowsingForPeers()
    }
}
#endif
