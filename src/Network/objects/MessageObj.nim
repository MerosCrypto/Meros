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
            BlockRequest = 6,
            ElementRequest = 7,
            EntryRequest = 8,
            GetBlockHash = 10,
            BlockHash = 11,
            DataMissing = 19,
            SyncingOver = 20,

            Claim = 21,
            Send = 22,
            Receive = 23,
            Data = 24,

            SignedVerification = 27,

            Block = 32,
            Verification = 33,

            #End is used to mark the end of the Enum.
            #We need to check if we were sent a valid MessageType, and we do this via checking if value < End.
            End = 39

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
    entry: Entry
): SyncEntryResponse {.forceCheck: [].} =
    case entry.descendant:
        of EntryType.Mint:
            doAssert(false, "Sync Entry Received a Mint and tried to handle it.")

        of EntryType.Claim:
            result = SyncEntryResponse(
                entry: EntryType.Claim,
                claim: cast[Claim](entry)
            )
        of EntryType.Send:
            result = SyncEntryResponse(
                entry: EntryType.Send,
                send: cast[Send](entry)
            )
        of EntryType.Receive:
            result = SyncEntryResponse(
                entry: EntryType.Receive,
                receive: cast[Receive](entry)
            )
        of EntryType.Data:
            result = SyncEntryResponse(
                entry: EntryType.Data,
                data: cast[Data](entry)
            )

#Stringify.
func toString*(
    msg: Message
): string {.forceCheck: [].} =
    char(msg.content) & msg.message
