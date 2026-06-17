import Foundation
import NIOCore
import NIOSSH

/// Handler de canal SSH « session » qui demande un PTY + un shell interactif,
/// remonte la sortie distante vers une fermeture, et encapsule la saisie
/// utilisateur (`ByteBuffer`) en `SSHChannelData`.
final class PTYChannelHandler: ChannelDuplexHandler {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = SSHChannelData

    private let cols: Int
    private let rows: Int
    private let onOutput: (Data) -> Void
    private let onClose: (Error?) -> Void

    init(
        cols: Int,
        rows: Int,
        onOutput: @escaping (Data) -> Void,
        onClose: @escaping (Error?) -> Void
    ) {
        self.cols = cols
        self.rows = rows
        self.onOutput = onOutput
        self.onClose = onClose
    }

    func handlerAdded(context: ChannelHandlerContext) {
        context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).whenFailure { error in
            context.fireErrorCaught(error)
        }
    }

    func channelActive(context: ChannelHandlerContext) {
        // Demande un pseudo-terminal puis ouvre un shell. NIOSSH préserve l'ordre
        // d'émission sur la même boucle d'évènements.
        let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: "xterm-256color",
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: SSHTerminalModes([:])
        )
        context.triggerUserOutboundEvent(ptyRequest, promise: nil)
        context.triggerUserOutboundEvent(SSHChannelRequestEvent.ShellRequest(wantReply: true), promise: nil)
        context.fireChannelActive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = unwrapInboundIn(data)
        // stdout (.channel) et stderr (.stdErr) sont tous deux affichés dans le terminal.
        guard case var .byteBuffer(buffer) = channelData.data else { return }
        if let bytes = buffer.readBytes(length: buffer.readableBytes), !bytes.isEmpty {
            onOutput(Data(bytes))
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
