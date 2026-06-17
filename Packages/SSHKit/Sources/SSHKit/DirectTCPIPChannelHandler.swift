import Foundation
import NIOCore
import NIOSSH

/// Handler d'un canal SSH **`direct-tcpip`** : simple passe-plat d'octets
/// (`SSHChannelData` ⇄ `ByteBuffer`), sans requête de sous-système (la cible est
/// portée par l'ouverture du canal). Base commune au **port forwarding** local
/// et aux **jump hosts** (ProxyJump).
final class DirectTCPIPChannelHandler: ChannelDuplexHandler {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = SSHChannelData

    private let onData: (Data) -> Void
    private let onClose: (Error?) -> Void

    init(onData: @escaping (Data) -> Void, onClose: @escaping (Error?) -> Void) {
        self.onData = onData
        self.onClose = onClose
    }

    func handlerAdded(context: ChannelHandlerContext) {
        context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).whenFailure { error in
            context.fireErrorCaught(error)
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = unwrapInboundIn(data)
        guard case var .byteBuffer(buffer) = channelData.data else { return }
        if let bytes = buffer.readBytes(length: buffer.readableBytes), !bytes.isEmpty {
            onData(Data(bytes))
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let buffer = unwrapOutboundIn(data)
        context.write(wrapOutboundOut(SSHChannelData(type: .channel, data: .byteBuffer(buffer))), promise: promise)
    }

    func channelInactive(context: ChannelHandlerContext) {
        onClose(nil)
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        onClose(error)
        context.close(promise: nil)
    }
}

/// Convertit `SSHChannelData` ⇄ `ByteBuffer` **dans la pile** (sans callback),
/// pour faire tourner un `NIOSSHHandler` imbriqué au-dessus d'un canal
/// `direct-tcpip` — c'est le mécanisme des **jump hosts** (ProxyJump) : la
/// session SSH cible voyage à travers un tunnel ouvert sur le jump.
final class SSHChannelDataUnwrapper: ChannelDuplexHandler {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = SSHChannelData

    func handlerAdded(context: ChannelHandlerContext) {
        context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).whenFailure { error in
            context.fireErrorCaught(error)
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = unwrapInboundIn(data)
        guard case let .byteBuffer(buffer) = channelData.data else { return }
        context.fireChannelRead(wrapInboundOut(buffer))
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let buffer = unwrapOutboundIn(data)
        context.write(wrapOutboundOut(SSHChannelData(type: .channel, data: .byteBuffer(buffer))), promise: promise)
    }
}

/// Relaie les octets reçus vers un **canal pair** (et propage la fermeture).
/// Deux instances croisées bâtissent un pont bidirectionnel entre un socket local
/// et un canal `direct-tcpip` — c'est le mécanisme du **port forwarding** local.
final class GlueHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    private var peer: Channel?

    func setPeer(_ channel: Channel) { peer = channel }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        peer?.writeAndFlush(buffer, promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        peer?.close(promise: nil)
        peer = nil
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.close(promise: nil)
    }
}
