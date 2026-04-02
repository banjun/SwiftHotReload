#if DEBUG || os(macOS)
import Foundation
@preconcurrency import MultipeerConnectivity

struct RuntimePeer: Sendable {
    /// route for sending dylib
    var session: MCSession
    /// the destination peerID that will load the dylib on runtime
    var peerID: MCPeerID
    /// build environments for the destination
    var builderParams: Builder.InputParameters?
}
#endif
