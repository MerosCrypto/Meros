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

            Syncing = 1,
            SyncingAcknowledged = 2,
            BlockRequest = 4,
            VerificationRequest = 5,
            EntryRequest = 6,
            DataMissing = 15,
            SyncingOver = 16,

            Claim = 17,
            Send = 18,
            Receive = 19,
            Data = 20,

            SignedVerification = 23,

            Block = 28,
            Verification = 29,

            #End is used to mark the end of the Enum.
            #We need to check if we were sent a valid MessageType, and we do this via checking if value < End.
            End = 35

        #Message object.
        Message* = object
            client* {.final.}: int
            content* {.final.}: MessageType
            len* {.final.}: int
            message* {.final.}: string

        #syncEntry response.
        #This has its own type to stop a segfault that occurs when we cast things around.
        SyncEntryResponse* = object
            case entry*: EntryType:
                of EntryType.Claim:
                    claim* {.final.}: Claim
                of EntryType.Send:
                    send* {.final.}: Send
                of EntryType.Receive:
                    receive* {.final.}: Receive
                of EntryType.Data:
                    data* {.final.}: Data
                else:
                    discard

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

#SyncEntryResponse constructors.
func newSyncEntryResponse*(
    claim: Claim
): SyncEntryResponse {.forceCheck: [].} =
    SyncEntryResponse(
        entry: EntryType.Claim,
        claim: claim
    )

func newSyncEntryResponse*(
    send: Send
): SyncEntryResponse {.forceCheck: [].} =
    SyncEntryResponse(
        entry: EntryType.Send,
        send: send
    )

func newSyncEntryResponse*(
    recv: Receive
): SyncEntryResponse {.forceCheck: [].} =
    SyncEntryResponse(
        entry: EntryType.Receive,
        receive: recv
    )

func newSyncEntryResponse*(
    data: Data
): SyncEntryResponse {.forceCheck: [].} =
    SyncEntryResponse(
        entry: EntryType.Data,
        data: data
    )

#Stringify.
func `$`*(
    msg: Message
): string {.forceCheck: [].} =
    char(msg.content) & msg.message
