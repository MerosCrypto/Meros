#finals lib.
import finals

finalsd:
    type
        #Message Type enum.
        MessageType* = enum
            Send = 0,
            Receive = 1,
            Data = 2,
            Verification = 3,
            MeritRemoval = 4

        #Message obkect.
        Message* = ref object of RootObj
            client* {.final.}: int
            network* {.final.}: int
            version* {.final.}: int
            content* {.final.}: MessageType
            header* {.final.}: string
            message* {.final.}: string

#Constructor for incoming data.
proc newMessage*(
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
proc newMessage*(
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
proc `$`*(msg: Message): string {.raises: [].} =
    msg.header & msg.message
