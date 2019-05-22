#Errors lib.
import ../../lib/Errors

#Lattice Entries (we don't just import Lattice due to a circular dependcy).
import ../../Database/Lattice/objects/EntryObj
import ../../Database/Lattice/objects/ClaimObj
import ../../Database/Lattice/objects/SendObj
import ../../Database/Lattice/objects/ReceiveObj
import ../../Database/Lattice/objects/DataObj

#Serialization common lib.
import ../Serialize/SerializeCommon

#finals lib.
import finals

finalsd:
    type
        #Message Type enum. Even though pure is no longer enforced, it does solve ambiguity issues.
        MessageType* {.pure.} = enum
            Handshake = 0,
            BlockHeight = 1,

            Syncing = 2,
            SyncingAcknowledged = 3,
            BlockHeaderRequest = 7,
            BlockBodyRequest = 8,
            ElementRequest = 9,
            EntryRequest = 10,
            GetBlockHash = 11,
            BlockHash = 12,
            DataMissing = 20,
            SyncingOver = 21,

            Claim = 22,
            Send = 23,
            Receive = 24,
            Data = 25,

            SignedVerification = 28,

            BlockHeader = 34,
            BlockBody = 35,
            Verification = 36,

            #End is used to mark the end of the Enum.
            #We need to check if we were sent a valid MessageType, and we do this via checking if value < End.
            End = 41

        #Message object.
        Message* = object
            client* {.final.}: int
            content* {.final.}: MessageType
            len* {.final.}: int
            message* {.final.}: string

#Finalize the Message.
func finalize(
    msg: var Message
) {.forceCheck: [].} =
    msg.ffinalizeClient()
    msg.ffinalizeContent()
    msg.ffinalizeLen()
    msg.ffinalizeMessage()

#Constructor for incoming data.
func newMessage*(
    client: int,
    content: MessageType,
    len: int,
    message: string
): Message {.forceCheck: [].} =
    result = Message(
        client: client,
        content: content,
        len: len,
        message: message
    )
    result.finalize()

#Constructor for outgoing data.
func newMessage*(
    content: MessageType,
    message: string = ""
): Message {.forceCheck: [].} =
    #Create the Message.
    result = Message(
        client: 0,
        content: content,
        len: message.len,
        message: message
    )
    result.finalize()

#Stringify.
func toString*(
    msg: Message
): string {.forceCheck: [].} =
    char(msg.content) & msg.message
