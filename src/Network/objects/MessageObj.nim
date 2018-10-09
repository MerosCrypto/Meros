#finals lib.
import finals

finalsd:
    type
        #Message Type enum.
        MessageType* = enum
            Verification = 0,
            Block = 1,
            Send = 2,
            Receive = 3,
            Data = 4,
            MeritRemoval = 5

        #Message obkect.
        Message* = ref object of RootObj
            client* {.final.}: int
            network* {.final.}: int
            version* {.final.}: int
            content* {.final.}: MessageType
            header* {.final.}: string
            message* {.final.}: string

#Constructor for incoming data.
func newMessage*(
    client: int,
    network: int,
    version: int,
    content: MessageType,
    header: string,
    message: string
): Message {.raises: [].} =
    Message(
        client: client,
        network: network,
        version: version,
        content: content,
        header: header,
        message: message
    )

#Constructor for outgoing data.
func newMessage*(
    network: int,
    version: int,
    content: MessageType,
    message: string
): Message {.raises: [].} =
    Message(
        network: network,
        version: version,
        content: content,
        header: char(network) & char(version) & char(content) & char(message.len),
        message: message
    )

#Stringify.
func `$`*(msg: Message): string {.raises: [].} =
    msg.header & msg.message
