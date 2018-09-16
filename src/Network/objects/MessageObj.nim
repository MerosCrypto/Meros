#SetOnce lib.
import SetOnce

type
    #Message Type enum.
    MessageType* = enum
        Send = 0,
        Receive = 1,
        Data = 2,
        Verification = 3,
        MeritRemoval = 4

    Message* = ref object of RootObj
        client*: SetOnce[int]
        network*: SetOnce[int]
        version*: SetOnce[int]
        content*: SetOnce[MessageType]
        header*: SetOnce[string]
        message*: SetOnce[string]

#Constructor.
proc newMessage*(
    client: int,
    network: int,
    version: int,
    content: MessageType,
    header: string,
    message: string
): Message {.raises: [ValueError].} =
    result = Message()
    result.client.value = client
    result.network.value = network
    result.version.value = version
    result.content.value = content
    result.header.value = header
    result.message.value = message

#Stringify.
proc `$`*(msg: Message): string =
    msg.header & msg.message
