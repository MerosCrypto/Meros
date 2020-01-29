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
        Syncing                   = 1,
        BlockchainTail            = 2,

        PeersRequest              = 3,
        Peers                     = 4,
        BlockListRequest          = 5,
        BlockList                 = 6,

        BlockHeaderRequest        = 8,
        BlockBodyRequest          = 9,
        SketchHashesRequest       = 10,
        SketchHashRequests        = 11,
        TransactionRequest        = 12,
        DataMissing               = 13,

        Claim                     = 14,
        Send                      = 15,
        Data                      = 16,

        SignedVerification        = 19,
        SignedSendDifficulty      = 20,
        SignedDataDifficulty      = 21,
        SignedMeritRemoval        = 23,

        BlockHeader               = 25,
        BlockBody                 = 26,
        SketchHashes              = 27,
        VerificationPacket        = 28,

        #End is used to mark the end of the Enum.
        #We need to check if we were sent a valid MessageType, and we do this via checking if value < End.
        End = 29

    #Message object.
    Message* = object
        peer*: int
        content*: MessageType
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
const LIVE_LENS*: Table[MessageType, seq[int]] = {
    MessageType.Handshake:                 @[BYTE_LEN + BYTE_LEN + BYTE_LEN + PORT_LEN + HASH_LEN],
    MessageType.BlockchainTail:            @[HASH_LEN],

    MessageType.Claim:                     @[BYTE_LEN, -(HASH_LEN + BYTE_LEN), ED_PUBLIC_KEY_LEN + BLS_SIGNATURE_LEN],
    MessageType.Send:                      @[BYTE_LEN, -(HASH_LEN + BYTE_LEN), BYTE_LEN, -(ED_PUBLIC_KEY_LEN + MEROS_LEN), ED_SIGNATURE_LEN + INT_LEN],
    MessageType.Data:                      @[HASH_LEN, BYTE_LEN, -BYTE_LEN, BYTE_LEN, ED_SIGNATURE_LEN + INT_LEN],

    MessageType.SignedVerification:        @[NICKNAME_LEN + HASH_LEN + BLS_SIGNATURE_LEN],
    MessageType.SignedSendDifficulty:      @[NICKNAME_LEN + INT_LEN + HASH_LEN + BLS_SIGNATURE_LEN],
    MessageType.SignedDataDifficulty:      @[NICKNAME_LEN + INT_LEN + HASH_LEN + BLS_SIGNATURE_LEN],
    MessageType.SignedMeritRemoval:        @[NICKNAME_LEN + BYTE_LEN + BYTE_LEN, 0, 0, BLS_SIGNATURE_LEN - 1],

    MessageType.BlockHeader:               @[BLOCK_HEADER_DATA_LEN, 0, INT_LEN + INT_LEN + BLS_SIGNATURE_LEN]
}.toTable()

const SYNC_LENS*: Table[MessageType, seq[int]] = {
    MessageType.Syncing:                   LIVE_LENS[MessageType.Handshake],
    MessageType.BlockchainTail:            LIVE_LENS[MessageType.BlockchainTail],

    MessageType.PeersRequest:              @[],
    MessageType.Peers:                     @[BYTE_LEN, PEER_LEN],
    MessageType.BlockListRequest:          @[BYTE_LEN + BYTE_LEN + HASH_LEN],
    MessageType.BlockList:                 @[BYTE_LEN, -HASH_LEN, HASH_LEN],

    MessageType.BlockHeaderRequest:        @[HASH_LEN],
    MessageType.BlockBodyRequest:          @[HASH_LEN],
    MessageType.SketchHashesRequest:       @[HASH_LEN],
    MessageType.SketchHashRequests:        @[HASH_LEN, INT_LEN, -SKETCH_HASH_LEN],
    MessageType.TransactionRequest:        @[HASH_LEN],
    MessageType.DataMissing:               @[],

    MessageType.Claim:                     LIVE_LENS[MessageType.Claim],
    MessageType.Send:                      LIVE_LENS[MessageType.Send],
    MessageType.Data:                      LIVE_LENS[MessageType.Data],

    MessageType.BlockHeader:               LIVE_LENS[MessageType.BlockHeader],
    MessageType.BlockBody:                 @[HASH_LEN, INT_LEN, -SKETCH_HASH_LEN, INT_LEN, 0, BLS_SIGNATURE_LEN],
    MessageType.SketchHashes:              @[INT_LEN, -SKETCH_HASH_LEN],
    MessageType.VerificationPacket:        @[NICKNAME_LEN, -NICKNAME_LEN, HASH_LEN]
}.toTable()

#Constructor for incoming data.
func newMessage*(
    peer: int,
    content: MessageType,
    message: string
): Message {.inline, forceCheck: [].} =
    Message(
        peer: peer,
        content: content,
        message: message
    )

#Constructor for outgoing data.
func newMessage*(
    content: MessageType,
    message: string = ""
): Message {.inline, forceCheck: [].} =
    Message(
        peer: 0,
        content: content,
        message: message
    )

#Stringify.
func toString*(
    msg: Message
): string {.inline, forceCheck: [].} =
    char(msg.content) & msg.message
