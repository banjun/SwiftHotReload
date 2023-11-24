#if DEBUG || os(macOS)
import Foundation
import MultipeerConnectivity

final actor Proxy {
    private let loader: Loader = .init()
    @Published private(set) var receivedDylibFiles: [URL] = []
    private var shouldConnectToBuilder: (_ title: String, _ message: String) async -> Bool
    func setShouldConnectToBuilder(_ shouldConnectToBuilder: @escaping (String, String) async -> Bool) { self.shouldConnectToBuilder = shouldConnectToBuilder }

    private let builderParams: Builder.InputParameters

    private let peerID: MCPeerID
    private let advertiser: MCNearbyServiceAdvertiser
    private var session: MCSession? {
        didSet {
            oldValue?.disconnect()
            session?.delegate = sessionDelegate
        }
    }
    private let advertiserDelegate: AdvertiserDelegate
    private let sessionDelegate: SessionDelegate

    enum Error: Swift.Error {
        case invalidFilePath(String)
        case fileAlreadyExists(String)
    }

    init(hostName: String = ProcessInfo().hostName, bundleID: String = Env.shared.CFBundleIdentifier!, processID: Int32 = ProcessInfo().processIdentifier, builderParams: Builder.InputParameters, shouldConnectToBuilder: @escaping (_ title: String, _ message: String) async -> Bool) {
        self.builderParams = builderParams
        self.shouldConnectToBuilder = shouldConnectToBuilder
        // the doc: The display name is intended for use in UI elements, and should be short and descriptive of the local peer. The maximum allowable length is 63 bytes in UTF-8 encoding. The displayName parameter may not be nil or an empty string.
        let displayName = String("\(hostName) \(bundleID)(\(processID))".utf8.prefix(63))!
        self.peerID = MCPeerID(displayName: displayName)
        self.advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: MultipeerConnectivityConstants.serverDiscoveryInfo, serviceType: MultipeerConnectivityConstants.serviceType)
        self.advertiserDelegate = AdvertiserDelegate()
        self.sessionDelegate = SessionDelegate()

        self.advertiser.delegate = self.advertiserDelegate

        Task {
            advertiserDelegate.proxy = self
            sessionDelegate.proxy = self
            await start()
        }
    }

    func start() {
        advertiser.startAdvertisingPeer()
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        session = nil
    }

    // MARK: - MCNearbyServiceAdvertiserDelegate

    private final class AdvertiserDelegate: NSObject, MCNearbyServiceAdvertiserDelegate {
        unowned var proxy: Proxy?
        override init() { super.init() }
        func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
            NSLog("%@", "🍓 \(#function) advertiser = \(advertiser), peerID = \(peerID), context = \(context?.count ?? 0) bytes")
            Task { await proxy?.advertiser(advertiser, didReceiveInvitationFromPeer: peerID, withContext: context, invitationHandler: invitationHandler) }
        }
        func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Swift.Error) {
            NSLog("%@", "🍓 \(#function) advertiser = \(advertiser), error = \(error)")
            Task { await proxy?.advertiser(advertiser, didNotStartAdvertisingPeer: error) }
        }
    }

    private func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("%@", "🍓 \(#function) advertiser = \(advertiser), peerID = \(peerID), context = \(context?.count ?? 0) bytes")
        guard session == nil else {
            NSLog("%@", "🍓 \(#function) ignored additional session")
            return
        }

        Task {
            let trusted = await shouldConnectToBuilder("⚠️ Connect to a Builder \(peerID)?", "SwiftHotReload loads any code from the Builder")
            if trusted {
                self.session = MCSession(peer: self.peerID, securityIdentity: nil, encryptionPreference: .required)
            }
            invitationHandler(trusted, self.session)
        }
    }

    private func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Swift.Error) {
        NSLog("%@", "🍓 \(#function) advertiser = \(advertiser), error = \(error)")
    }

    // MARK: - MCSessionDelegate

    private final class SessionDelegate: NSObject, MCSessionDelegate {
        unowned var proxy: Proxy?
        override init() { super.init() }

        func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
            NSLog("%@", "🍓 \(#function) peerID = \(peerID), state = \(state)")
            Task { await proxy?.session(session, peer: peerID, didChange: state) }
        }

        func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
            NSLog("%@", "🍓 \(#function) data = \(data.count) bytes, peerID = \(peerID)")
        }

        func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
            NSLog("%@", "🍓 \(#function) stream = \(stream), streamName = \(streamName), peerID = \(peerID)")
        }

        func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
            NSLog("%@", "🍓 \(#function) resourceName = \(resourceName), peerID = \(peerID), progress = \(progress)")
        }

        func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Swift.Error?) {
            NSLog("%@", "🍓 \(#function) resourceName = \(resourceName), peerID = \(peerID), localURL = \(String(describing: localURL)), error = \(String(describing: error))")
            Task { await proxy?.session(session, didFinishReceivingResourceWithName: resourceName, fromPeer: peerID, at: localURL, withError: error) }
        }
    }

    private func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .notConnected:
            self.session = nil
        case .connecting: break
        case .connected:
            do {
                NSLog("%@", "🍓 \(#function) connected: sending builderParams = \(builderParams)")
                let payload = try JSONEncoder().encode(builderParams)
                try self.session?.send(payload, toPeers: [peerID], with: .reliable)
            } catch {
                NSLog("%@", "🍓 \(#function) error = \(error)")
            }
        @unknown default: break
        }
    }

    private func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Swift.Error?) {
        guard let localURL else { return }
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("SwiftHotReload")
            .appendingPathComponent("dylibs")
        guard let filename = resourceName.components(separatedBy: "/").last else { return } // { throw Error.invalidFilePath(resourceName) }
        let tmpDylibPath = tmpDir.appendingPathComponent(filename)

        do {
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            // guard !FileManager.default.fileExists(atPath: tmpDylibPath.path) else { return }

            if FileManager.default.fileExists(atPath: tmpDylibPath.path) {
                try FileManager.default.removeItem(atPath: tmpDylibPath.path)
            }

            try FileManager.default.copyItem(at: localURL, to: tmpDylibPath)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: tmpDylibPath.path)
        } catch {
            NSLog("%@", "🍓 \(#function) line \(#line) error = \(error)")
        }
        Task {
            do {
                try await loader.load(dylibPath: tmpDylibPath)
                receivedDylibFiles.append(tmpDylibPath)
            } catch {
                NSLog("%@", "🍓 \(#function) line \(#line) error = \(error)")
            }
        }
    }
}
#endif
