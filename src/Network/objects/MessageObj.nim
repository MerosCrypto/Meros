#Util.
import ../../lib/Util

#finals lib.
import finals

finalsd:
    type
        #Message Type enum.
        MessageType* = enum
            Handshake = 0,
            Verification = 1,
            Block = 2,
            Claim = 3,
            Send = 4,
            Receive = 5,
            Data = 6,
            EntryRequest = 7

        #Message object.
        Message* = ref object of RootObj
            client* {.final.}: uint
            network* {.final.}: uint
            protocol* {.final.}: uint
            content* {.final.}: MessageType
            len* {.final.}: uint
            header* {.final.}: string
            message* {.final.}: string

#Finalize the Message.
func finalize(
    msg: Message
) {.raises: [].} =
    msg.ffinalizeClient()
    msg.ffinalizeNetwork()
    msg.ffinalizeProtocol()
    msg.ffinalizeContent()
    msg.ffinalizeLen()
    msg.ffinalizeHeader()
    msg.ffinalizeMessage()

#Constructor for incoming data.
func newMessage*(
    client: uint,
    network: uint,
    protocol: uint,
    content: MessageType,
    len: uint,
    header: string,
    message: string
): Message {.raises: [].} =
    result = Message(
        client: client,
        network: network,
        protocol: protocol,
        content: content,
        len: len,
        header: header,
        message: message
    )
    result.finalize()

#Constructor for outgoing data.
func newMessage*(
    network: uint,
    protocol: uint,
    content: MessageType,
    message: string
): Message {.raises: [].} =
    #Serialize the length.
    var
        len: int = message.len
        length: string = ""
    while len > 255:
        len = len mod 255
        length &= char(255)
    length &= char(len)

    #Create the Message.
    result = Message(
        network: network,
        protocol: protocol,
        content: content,
        len: uint(message.len),
        header: char(network) & char(protocol) & char(content) & length,
        message: message
    )
    result.finalize()

#Stringify.
func `$`*(msg: Message): string {.raises: [].} =
    msg.header & msg.message
