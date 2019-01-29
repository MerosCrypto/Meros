#Serialization common lib.
import ../Serialize/SerializeCommon

#finals lib.
import finals

finalsd:
    type
        #Message Type enum.
        MessageType* = enum
            Handshake = 0,
            HandshakeOver = 1,

            Syncing = 2,
            BlockRequest = 3,
            VerificationRequest = 4,
            EntryRequest = 5,
            DataMissing = 6,
            SyncingOver = 7,

            Claim = 8,
            Send = 9,
            Receive = 10,
            Data = 11,
            MemoryVerification = 12,
            Verification = 13,
            Block = 14

        #Message object.
        Message* = ref object of RootObj
            client* {.final.}: uint
            content* {.final.}: MessageType
            len* {.final.}: uint
            header* {.final.}: string
            message* {.final.}: string

#Finalize the Message.
func finalize(
    msg: Message
) {.raises: [].} =
    msg.ffinalizeClient()
    msg.ffinalizeContent()
    msg.ffinalizeLen()
    msg.ffinalizeHeader()
    msg.ffinalizeMessage()

#Constructor for incoming data.
func newMessage*(
    client: uint,
    content: MessageType,
    len: uint,
    header: string,
    message: string
): Message {.raises: [].} =
    result = Message(
        client: client,
        content: content,
        len: len,
        header: header,
        message: message
    )
    result.finalize()

#Constructor for outgoing data.
func newMessage*(
    content: MessageType,
    message: string
): Message {.raises: [].} =
    #Create the Message.
    result = Message(
        content: content,
        len: uint(message.len),
        header: char(content) & message.lenPrefix,
        message: message
    )
    result.finalize()

#Stringify.
func `$`*(msg: Message): string {.raises: [].} =
    msg.header & msg.message
