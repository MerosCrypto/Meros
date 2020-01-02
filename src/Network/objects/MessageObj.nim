#Errors lib.
import ../../lib/Errors

#Serialization common lib.
import ../Serialize/SerializeCommon

#Hashes standard lib.
import hashes

#Tables standard lib.
import tables

type
    #Message Type enum. Even though pure is no longer enforced, it does solve ambiguity issues.
    MessageType* {.pure.} = enum
        Handshake                 = 0,
        BlockchainTail            = 1,

        Syncing                   = 2,
        SyncingAcknowledged       = 3,
        BlockListRequest          = 6,
        BlockList                 = 7,

        BlockHeaderRequest        = 9,
        BlockBodyRequest          = 10,
        SketchHashesRequest       = 11,
        SketchHashRequests        = 12,
        TransactionRequest        = 13,
        DataMissing               = 14,
        SyncingOver               = 15,

        Claim                     = 16,
        Send                      = 17,
        Data                      = 18,

        SignedVerification        = 21,
        SignedDataDifficulty      = 23,
        SignedMeritRemoval        = 25,

        BlockHeader               = 27,
        BlockBody                 = 28,
        SketchHashes              = 29,
        VerificationPacket        = 30,

        #End is used to mark the end of the Enum.
        #We need to check if we were sent a valid MessageType, and we do this via checking if value < End.
        End = 31

    #Message object.
    Message* = object
        client*: int
        content*: MessageType
        len*: int
        message*: string

#Hash a MessageType.
proc hash*(
    msgType: MessageType
): Hash {.inline, forceCheck: [].} =
    hash(ord(msgType))

#Lengths of messages.
#An empty array means the message was just the header.
#A positive number means read X bytes.
#A negative number means read the last length * X bytes.
#A zero means custom logic should be used.
const MESSAGE_LENS*: Table[MessageType, seq[int]] = {
    MessageType.Handshake:                 @[BYTE_LEN + BYTE_LEN + BYTE_LEN + HASH_LEN],
    MessageType.BlockchainTail:            @[HASH_LEN],

    MessageType.Syncing:                   @[],
    MessageType.SyncingAcknowledged:       @[],
    MessageType.BlockListRequest:          @[BYTE_LEN + BYTE_LEN + HASH_LEN],
    MessageType.BlockList:                 @[BYTE_LEN, -HASH_LEN, HASH_LEN],

    MessageType.BlockHeaderRequest:        @[HASH_LEN],
    MessageType.BlockBodyRequest:          @[HASH_LEN],
    MessageType.SketchHashesRequest:       @[HASH_LEN],
    MessageType.SketchHashRequests:        @[HASH_LEN, INT_LEN, -SKETCH_HASH_LEN],
    MessageType.TransactionRequest:        @[HASH_LEN],
    MessageType.DataMissing:               @[],
    MessageType.SyncingOver:               @[],

    MessageType.Claim:                     @[BYTE_LEN, -(HASH_LEN + BYTE_LEN), ED_PUBLIC_KEY_LEN + BLS_SIGNATURE_LEN],
    MessageType.Send:                      @[BYTE_LEN, -(HASH_LEN + BYTE_LEN), BYTE_LEN, -(ED_PUBLIC_KEY_LEN + MEROS_LEN), ED_SIGNATURE_LEN + INT_LEN],
    MessageType.Data:                      @[HASH_LEN, BYTE_LEN, -BYTE_LEN, ED_SIGNATURE_LEN + INT_LEN],

    MessageType.SignedVerification:        @[NICKNAME_LEN + HASH_LEN + BLS_SIGNATURE_LEN],
    MessageType.SignedMeritRemoval:        @[NICKNAME_LEN + BYTE_LEN + BYTE_LEN, 0, BYTE_LEN, 0, BLS_SIGNATURE_LEN],

    MessageType.BlockHeader:               @[BLOCK_HEADER_DATA_LEN, 0, INT_LEN + INT_LEN + BLS_SIGNATURE_LEN],
    MessageType.BlockBody:                 @[INT_LEN, -SKETCH_HASH_LEN, INT_LEN, 0, BLS_SIGNATURE_LEN],
    MessageType.SketchHashes:              @[INT_LEN, -SKETCH_HASH_LEN],
    MessageType.VerificationPacket:        @[NICKNAME_LEN, -NICKNAME_LEN, HASH_LEN]
}.toTable()

#Constructor for incoming data.
func newMessage*(
    client: int,
    content: MessageType,
    len: int,
    message: string
): Message {.inline, forceCheck: [].} =
    Message(
        client: client,
        content: content,
        len: len,
        message: message
    )

#Constructor for outgoing data.
func newMessage*(
    content: MessageType,
    message: string = ""
): Message {.inline, forceCheck: [].} =
    Message(
        client: 0,
        content: content,
        len: message.len,
        message: message
    )

#Stringify.
func toString*(
    msg: Message
): string {.inline, forceCheck: [].} =
    char(msg.content) & msg.message
