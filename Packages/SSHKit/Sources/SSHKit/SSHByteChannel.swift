import Foundation
import NIOCore

/// Canal d'octets bidirectionnel au-dessus d'un canal SSH de sous-système.
///
/// Cache entièrement NIO aux consommateurs (ex. SFTPKit) : on lit la sortie via
/// l'`AsyncStream<Data>` ``inbound`` et on écrit via ``send(_:)``.
public final class SSHByteChannel: @unchecked Sendable {
    private let channel: Channel
    private let inboundContinuation: AsyncStream<Data>.Continuation

    /// Flux d'octets reçus du pair distant.
    public let inbound: AsyncStream<Data>

    init(
        channel: Channel,
        inbound: AsyncStream<Data>,
        continuation: AsyncStream<Data>.Continuation
    ) {
        self.channel = channel
        self.inbound = inbound
        self.inboundContinuation = continuation
    }

    /// Envoie des octets bruts vers le pair distant.
    public func send(_ data: Data) async throws {
        var buffer = channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        try await channel.writeAndFlush(buffer).get()
    }

    /// Ferme le canal.
    public func close() async {
        try? await channel.close().get()
        inboundContinuation.finish()
    }
}
