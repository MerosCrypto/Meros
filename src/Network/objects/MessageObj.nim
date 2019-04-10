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
            BlockRequest = 2,
            VerificationRequest = 3,
            EntryRequest = 4,
            DataMissing = 5,
            SyncingOver = 6,

            Claim = 7,
            Send = 8,
            Receive = 9,
            Data = 10,
            MemoryVerification = 11,
            Block = 12,
            Verification = 13

        #Message object.
        Message* = ref object of RootObj
            client* {.final.}: uint
            content* {.final.}: MessageType
            len* {.final.}: uint
            message* {.final.}: string

        #syncEntry response.
        #This has its own type to stop a segfault that occurs when we cast things around.
        SyncEntryResponse* = ref object of RootObj
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
    msg: Message
) {.raises: [].} =
    msg.ffinalizeClient()
    msg.ffinalizeContent()
    msg.ffinalizeLen()
    msg.ffinalizeMessage()

#Constructor for incoming data.
func newMessage*(
    client: uint,
    content: MessageType,
    len: uint,
    message: string
): Message {.raises: [].} =
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
): Message {.raises: [].} =
    #Create the Message.
    result = Message(
        client: 0,
        content: content,
        len: uint(message.len),
        message: message
    )
    result.finalize()

#SyncEntryResponse constructors.
func newSyncEntryResponse*(claim: Claim): SyncEntryResponse {.raises: [].} =
    SyncEntryResponse(
        entry: EntryType.Claim,
        claim: claim
    )

func newSyncEntryResponse*(send: Send): SyncEntryResponse {.raises: [].} =
    SyncEntryResponse(
        entry: EntryType.Send,
        send: send
    )

func newSyncEntryResponse*(recv: Receive): SyncEntryResponse {.raises: [].} =
    SyncEntryResponse(
        entry: EntryType.Receive,
        receive: recv
    )

func newSyncEntryResponse*(data: Data): SyncEntryResponse {.raises: [].} =
    SyncEntryResponse(
        entry: EntryType.Data,
        data: data
    )

#Stringify.
func `$`*(msg: Message): string {.raises: [].} =
    char(msg.content) & msg.message
