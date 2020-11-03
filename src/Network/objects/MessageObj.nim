import hashes, tables

import ../../lib/Errors

import ../Serialize/SerializeCommon

type
  #Message Type enum. Even though pure is no longer enforced, it does solve ambiguity issues.
  MessageType* {.pure.} = enum
    Handshake      = 0,
    Syncing        = 1,
    Busy           = 2,
    BlockchainTail = 3,

    PeersRequest     = 4,
    Peers            = 5,
    BlockListRequest = 6,
    BlockList        = 7,

    BlockHeaderRequest  = 9,
    BlockBodyRequest    = 10,
    SketchHashesRequest = 11,
    SketchHashRequests  = 12,
    TransactionRequest  = 13,
    DataMissing         = 14,

    Claim = 15,
    Send  = 16,
    Data  = 17,

    SignedVerification   = 20,
    SignedSendDifficulty = 21,
    SignedDataDifficulty = 22,
    SignedMeritRemoval   = 24,

    BlockHeader        = 26,
    BlockBody          = 27,
    SketchHashes       = 28,
    VerificationPacket = 29,

    #End is used to mark the end of the Enum.
    #We need to check if we were sent a valid MessageType, and we do this via checking if value < End.
    End = 30

  Message* = object
    peer*: int
    content*: MessageType
    message*: string

proc hash*(
  msgType: MessageType
): Hash {.inline, forceCheck: [].} =
  hash(ord(msgType))

#Lengths of messages.
#An empty array means the message was just the header.
#A positive number means read X bytes.
#A negative number means read the last length * X bytes.
#A zero means custom logic should be used.
const
  LIVE_LENS*: Table[MessageType, seq[int]] = {
    MessageType.Handshake:      @[0, 0, 0, PORT_LEN + HASH_LEN],
    MessageType.Busy:           @[BYTE_LEN, -PEER_LEN],
    MessageType.BlockchainTail: @[HASH_LEN],

    MessageType.Claim: @[BYTE_LEN, -(HASH_LEN + BYTE_LEN), ED_PUBLIC_KEY_LEN + BLS_SIGNATURE_LEN],
    MessageType.Send:  @[BYTE_LEN, -(HASH_LEN + BYTE_LEN), BYTE_LEN, -(ED_PUBLIC_KEY_LEN + MEROS_LEN), ED_SIGNATURE_LEN + INT_LEN],
    MessageType.Data:  @[HASH_LEN, BYTE_LEN, -BYTE_LEN, BYTE_LEN, ED_SIGNATURE_LEN + INT_LEN],

    MessageType.SignedVerification:   @[NICKNAME_LEN + HASH_LEN + BLS_SIGNATURE_LEN],
    MessageType.SignedSendDifficulty: @[NICKNAME_LEN + INT_LEN + INT_LEN + BLS_SIGNATURE_LEN],
    MessageType.SignedDataDifficulty: @[NICKNAME_LEN + INT_LEN + INT_LEN + BLS_SIGNATURE_LEN],
    MessageType.SignedMeritRemoval:   @[NICKNAME_LEN + BYTE_LEN + BYTE_LEN, 0, 0, BLS_SIGNATURE_LEN - 1],

    MessageType.BlockHeader: @[BLOCK_HEADER_DATA_LEN, 0, INT_LEN + INT_LEN + BLS_SIGNATURE_LEN]
  }.toTable()

  SYNC_LENS*: Table[MessageType, seq[int]] = {
    MessageType.Syncing:        LIVE_LENS[MessageType.Handshake],
    MessageType.Busy:           LIVE_LENS[MessageType.Busy],
    MessageType.BlockchainTail: LIVE_LENS[MessageType.BlockchainTail],

    MessageType.PeersRequest:     @[],
    MessageType.Peers:            LIVE_LENS[MessageType.Busy],
    MessageType.BlockListRequest: @[BYTE_LEN + HASH_LEN],
    MessageType.BlockList:        @[BYTE_LEN, -HASH_LEN, HASH_LEN],

    MessageType.BlockHeaderRequest:  @[HASH_LEN],
    MessageType.BlockBodyRequest:    @[HASH_LEN],
    MessageType.SketchHashesRequest: @[HASH_LEN],
    MessageType.SketchHashRequests:  @[HASH_LEN, INT_LEN, -SKETCH_HASH_LEN],
    MessageType.TransactionRequest:  @[HASH_LEN],
    MessageType.DataMissing:         @[],

    MessageType.Claim: LIVE_LENS[MessageType.Claim],
    MessageType.Send:  LIVE_LENS[MessageType.Send],
    MessageType.Data:  LIVE_LENS[MessageType.Data],

    MessageType.BlockHeader:        LIVE_LENS[MessageType.BlockHeader],
    MessageType.BlockBody:          @[HASH_LEN, INT_LEN, -SKETCH_HASH_LEN, INT_LEN, 0, BLS_SIGNATURE_LEN],
    MessageType.SketchHashes:       @[INT_LEN, -SKETCH_HASH_LEN],
    MessageType.VerificationPacket: @[NICKNAME_LEN, -NICKNAME_LEN, HASH_LEN]
  }.toTable()

  HANDSHAKE_LENS*: Table[MessageType, seq[int]] = {
    MessageType.Handshake: LIVE_LENS[MessageType.Handshake],
    MessageType.Syncing:   SYNC_LENS[MessageType.Syncing],
    MessageType.Busy:      LIVE_LENS[MessageType.Busy]
  }.toTable()

#Message constructors.
#This one is for incoming data; the following one is for outgoing data.
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

func newMessage*(
  content: MessageType,
  message: string = ""
): Message {.inline, forceCheck: [].} =
  Message(
    peer: 0,
    content: content,
    message: message
  )

func serialize*(
  msg: Message
): string {.inline, forceCheck: [].} =
  char(msg.content) & msg.message
