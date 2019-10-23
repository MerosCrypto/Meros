#Errors lib.
import ../../lib/Errors

#Serialization common lib.
import ../Serialize/SerializeCommon

#Finals lib.
import finals

#Hashes standard lib.
import hashes

#Tables standard lib.
import tables

finalsd:
    type
        #Message Type enum. Even though pure is no longer enforced, it does solve ambiguity issues.
        MessageType* {.pure.} = enum
            Handshake = 0,
            BlockchainTail = 1,

            Syncing = 2,
            SyncingAcknowledged = 3,
            BlockListRequest = 6,
            BlockList = 7,

            BlockHeaderRequest = 9,
            BlockBodyRequest = 10,
            BlockTransactionsRequest = 11,
            VerificationPacketRequest = 12,
            TransactionRequest = 13,
            SignedVerificationPacketRequest = 14,
            DataMissing = 15,
            SyncingOver = 16,

            Claim = 17,
            Send = 18,
            Data = 19,

            SignedVerification = 22,
            SignedVerificationPacket = 23,
            SignedMeritRemoval = 27,

            BlockHeader = 29,
            BlockBody = 30,
            BlockTransactions = 31,
            VerificationPacket = 32,

            #End is used to mark the end of the Enum.
            #We need to check if we were sent a valid MessageType, and we do this via checking if value < End.
            End = 33

        #Message object.
        Message* = object
            client* {.final.}: int
            content* {.final.}: MessageType
            len* {.final.}: int
            message* {.final.}: string

#Hash a MessageType.
proc hash*(
    msgType: MessageType
): Hash {.forceCheck: [].} =
    hash(ord(msgType))

#Lengths of messages.
#An empty array means the message was just the header.
#A positive number means read X bytes.
#A negative number means read the last positive section * X bytes,
#A zero means custom logic should be used.
const MESSAGE_LENS*: Table[MessageType, seq[int]] = {
    MessageType.Handshake: @[BYTE_LEN + BYTE_LEN + BYTE_LEN + HASH_LEN],
    MessageType.BlockchainTail: @[HASH_LEN],

    MessageType.Syncing: @[],
    MessageType.SyncingAcknowledged: @[],
    MessageType.BlockListRequest: @[BYTE_LEN + BYTE_LEN + HASH_LEN],
    MessageType.BlockList: @[BYTE_LEN, -HASH_LEN],

    MessageType.BlockHeaderRequest: @[HASH_LEN],
    MessageType.BlockBodyRequest: @[HASH_LEN],
    MessageType.BlockTransactionsRequest: @[HASH_LEN],
    MessageType.VerificationPacketRequest: @[HASH_LEN + HASH_LEN],
    MessageType.TransactionRequest: @[HASH_LEN],
    MessageType.DataMissing: @[],
    MessageType.SyncingOver: @[],

    MessageType.Claim: @[BYTE_LEN, -HASH_LEN, ED_PUBLIC_KEY_LEN + BLS_SIGNATURE_LEN],
    MessageType.Send: @[BYTE_LEN, -(HASH_LEN + BYTE_LEN), BYTE_LEN, -(ED_PUBLIC_KEY_LEN + MEROS_LEN), ED_SIGNATURE_LEN + INT_LEN],
    MessageType.Data: @[HASH_LEN, BYTE_LEN, -BYTE_LEN, ED_SIGNATURE_LEN + INT_LEN],

    MessageType.SignedVerification: @[NICKNAME_LEN + HASH_LEN + BLS_SIGNATURE_LEN],
    MessageType.SignedVerificationPacket: @[BYTE_LEN, -NICKNAME_LEN, HASH_LEN + BLS_SIGNATURE_LEN],
    MessageType.SignedMeritRemoval: @[NICKNAME_LEN + BYTE_LEN + BYTE_LEN, 0, BYTE_LEN, 0, BLS_SIGNATURE_LEN],

    MessageType.BlockHeader: @[INT_LEN + HASH_LEN + HASH_LEN + BYTE_LEN, 0, INT_LEN + INT_LEN + BLS_SIGNATURE_LEN],
    MessageType.BlockBody: @[INT_LEN, INT_LEN, INT_LEN, -SKETCH_ELEMENT_LEN, INT_LEN, 0, BLS_SIGNATURE_LEN],
    MessageType.BlockTransactions: @[INT_LEN, -HASH_LEN],
    MessageType.VerificationPacket: @[BYTE_LEN, -NICKNAME_LEN, HASH_LEN]
}.toTable()

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
