import Foundation
import NIOCore
import NIOSSH

/// Handler de canal SSH « session » qui demande un sous-système (ex. `sftp`)
/// et expose un simple passe-plat d'octets : `SSHChannelData` ⇄ `ByteBuffer`.
///
/// La sortie distante est remontée via ``onData`` ; la fermeture via ``onClose``.
final class SubsystemChannelHandler: ChannelDuplexHandler {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = SSHChannelData

    private let subsystem: String
    private let onData: (Data) -> Void
    private let onClose: (Error?) -> Void

    init(subsystem: String, onData: @escaping (Data) -> Void, onClose: @escaping (Error?) -> Void) {
        self.subsystem = subsystem
        self.onData = onData
        self.onClose = onClose
    }

    func handlerAdded(context: ChannelHandlerContext) {
        context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).whenFailure { error in
            context.fireErrorCaught(error)
        }
    }

    func channelActive(context: ChannelHandlerContext) {
        let request = SSHChannelRequestEvent.SubsystemRequest(subsystem: subsystem, wantReply: true)
        context.triggerUserOutboundEvent(request, promise: nil)
        context.fireChannelActive()
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
