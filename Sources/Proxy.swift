#if DEBUG
import Foundation
import MultipeerConnectivity

public final class ProxyReloader: ObservableObject {
    private let proxy: Proxy = .init()

    @Published public private(set) var dateReloaded: Date?

    public init() {
        Task {
            await proxy.$receivedDylibFiles.map {_ in Date() }.assign(to: &$dateReloaded)
            await proxy.start()
        }
    }
}

import Combine
public final class BuildHelper {
    private let fileMonitor: FileMonitor
    private let proxyBrowser = ProxyBrowser()
    private let core: Core

    @Published public private(set) var dateReloaded: Date?
    private var cancellables: Set<AnyCancellable> = []

    public init(monitoredSwiftFile: URL, env: Env = .shared, derivedData: URL? = nil, confBuildDirAppRandomString: String? = nil, mainModule: String? = nil, modules: [String] = [], configurationPlatform: String? = nil, arch: String? = nil, targetTriple: String? = nil, sdk: URL? = nil, platformName: String? = nil) {
        if env.DTPlatformName == "iphoneos" {
            NSLog("%@", "🍓 ⚠️ To do hot reloads standalone, the process host should be able to execute swiftc. ⚠️")
        }

        fileMonitor = .init(file: monitoredSwiftFile, platformName: platformName ?? env.DTPlatformName!)
        // TODO: core environments are differ for each peer targets.
        core = .init(builder: .init(targetSwiftFile: monitoredSwiftFile, env: env, derivedData: derivedData, confBuildDirAppRandomString: confBuildDirAppRandomString, mainModule: mainModule, modules: modules, configurationPlatform: configurationPlatform, arch: arch, targetTriple: targetTriple, sdk: sdk, platformName: platformName))

        Task {
            await fileMonitor.$fileChanges.compactMap {$0}.sink { [weak self] _ in
                self?.reload()
            }.store(in: &cancellables)

            await proxyBrowser.$route.sink { [weak self] route in
                guard let self else { return }
                Task { await self.core.setRoute(route) }
            }.store(in: &cancellables)
        }
    }

    private actor Core {
        private var counter: Int = 0

        private var builder: Builder
        private var route: (session: MCSession, server: MCPeerID, env: Env?)?

        init(builder: Builder) {
            self.builder = builder
        }

        func setRoute(_ route: (session: MCSession, server: MCPeerID, env: Env?)?) {
            self.route = route
//            self.builder = // TODO: builder parameters should be detemined after target build env is received...
        }

        func reload() async throws {
            counter += 1

            let dylibPath = try await builder.build(dylibFilename: "HotReload\(counter).dylib")
            guard let session = route?.session, let server = route?.server else { return }
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Swift.Error>) in
                session.sendResource(at: dylibPath, withName: dylibPath.lastPathComponent, toPeer: server) { error in
                    if let error { c.resume(throwing: error) }
                    else { c.resume() }
                }
            }
        }
    }

    public func reload() {
        Task { @MainActor in
            try await core.reload()
            dateReloaded = Date()
        }
    }

}

final actor ProxyBrowser {
    @Published private(set) var route: (session: MCSession, server: MCPeerID, env: Env?)? {
        didSet {
            route?.session.delegate = sessionDelegate
        }
    }
    private let peerID: MCPeerID
    private let browser: MCNearbyServiceBrowser
    private let browserDelegate: BrowserDelegate
    private let sessionDelegate: SessionDelegate = .init()

    init(hostName: String = ProcessInfo().hostName, bundleID: String = Env.shared.CFBundleIdentifier!, processID: Int32 = ProcessInfo().processIdentifier) {
        let displayName = String("Client[\(hostName)] \(bundleID)(\(processID))".utf8.prefix(63))!
        self.peerID = MCPeerID(displayName: displayName)
        self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Proxy.MultipeerConnectivityConstants.serviceType)
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
        guard info == Proxy.MultipeerConnectivityConstants.serverDiscoveryInfo else {
            NSLog("%@", "🍓 \(#function) ignore peer \(peerID) as it's not a server")
            return
        }
        guard route == nil else {
            NSLog("%@", "🍓 \(#function) ⚠️ TODO: support mutiple sessions")
            return
        }

        NSLog("%@", "🍓 \(#function) ⚠️ TODO: some auth to refrain from sending secret dylib to the unidentified server")
        let session = MCSession(peer: self.peerID, securityIdentity: nil, encryptionPreference: .required)
        self.browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        route = (session, peerID, nil)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@", "🍓 \(#function) peerID = \(peerID)")
        if route?.server == peerID {
            route = nil
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
            let env = try JSONDecoder().decode(Env.self, from: data)
            NSLog("%@", "🍓 \(#function) TODO: use env when build for the session: \(env)")
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

final actor Proxy {
    private let loader: Loader = .init()
    @Published private(set) var receivedDylibFiles: [URL] = []

    private let hostName: String
    private let bundleID: String
    private let processID: Int32

    private let peerID: MCPeerID
    private let advertiser: MCNearbyServiceAdvertiser
    private var session: MCSession? {
        didSet {
            session?.delegate = sessionDelegate
        }
    }
    private let advertiserDelegate: AdvertiserDelegate
    private let sessionDelegate: SessionDelegate

    enum MultipeerConnectivityConstants {
        /// MultipeerConnectivity service type
        /// The type of service to advertise. This should be a short text string that describes the app's networking protocol, in the same format as a Bonjour service type (without the transport protocol) and meeting the restrictions of RFC 6335 (section 5.1) governing Service Name Syntax. In particular, the string:
        /// * Must be 1–15 characters long
        /// * Can contain only ASCII lowercase letters, numbers, and hyphens
        /// * Must contain at least one ASCII letter
        /// * Must not begin or end with a hyphen
        /// * Must not contain hyphens adjacent to other hyphens.
        static let serviceType = "swifthotreload"
        static let serverDiscoveryInfo: [String: String] = ["SwiftHotReloadServer": "1"]
    }

    enum Error: Swift.Error {
        case invalidFilePath(String)
        case fileAlreadyExists(String)
    }

    init(hostName: String = ProcessInfo().hostName, bundleID: String = Env.shared.CFBundleIdentifier!, processID: Int32 = ProcessInfo().processIdentifier) {
        self.hostName = hostName
        self.bundleID = bundleID
        self.processID = processID
        // the doc: The display name is intended for use in UI elements, and should be short and descriptive of the local peer. The maximum allowable length is 63 bytes in UTF-8 encoding. The displayName parameter may not be nil or an empty string.
        let displayName = String("Server[\(hostName)] \(bundleID)(\(processID))".utf8.prefix(63))!
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
        session?.disconnect()
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
        guard session == nil else { return }

        let session = MCSession(peer: self.peerID, securityIdentity: nil, encryptionPreference: .required)
        self.session = session

        NSLog("%@", "🍓 \(#function) ⚠️ TODO: some auth to refrain from loading dylibs sent from the unidentified build helper")
        invitationHandler(true, session) // TODO: some auth
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
        case .notConnected: break
        case .connecting: break
        case .connected:
            do {
                let payload = try JSONEncoder().encode(Env.shared) // TODO: use parameterized env, or minimal data required for build
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
            guard !FileManager.default.fileExists(atPath: tmpDylibPath.path) else { return } // { throw Error.fileAlreadyExists(tmpDylibPath.path) }

            try FileManager.default.copyItem(at: localURL, to: tmpDylibPath)
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

    // MARK: -
}

#endif
