#Message type.
type Message* = ref object of RootObj
    client: int
    message: string

#Constructor.
proc newMessage*(client: int, message: string): Message {.raises: [].} =
    Message(
        client: client,
        message: message
    )

#Getters.
proc getClient*(msg: Message): int {.raises: [].} =
    msg.client
proc getMessage*(msg: Message): string {.raises: [].} =
    msg.message
