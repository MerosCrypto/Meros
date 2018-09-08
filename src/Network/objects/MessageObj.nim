type
    #Message Type enum.
    MessageType* = enum
        Send = 0,
        Receive = 1

    Message* = ref object of RootObj
        client: int
        network: int
        version: int
        content: MessageType
        header: string
        message: string

#Constructor.
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

#Getters.
proc getClient*(msg: Message): int {.raises: [].} =
    msg.client
proc getNetwork*(msg: Message): int {.raises: [].} =
    msg.network
proc getVersion*(msg: Message): int {.raises: [].} =
    msg.version
proc getContent*(msg: Message): MessageType {.raises: [].} =
    msg.content
proc getHeader*(msg: Message): string {.raises: [].} =
    msg.header
proc getMessage*(msg: Message): string {.raises: [].} =
    msg.message
