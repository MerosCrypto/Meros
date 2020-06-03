#Errors standard lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#BlockHeader object.
import ../../Database/Merit/objects/BlockHeaderObj

#Elements lib.
import ../../Database/Consensus/Elements/Elements

#Transaction lib.
import ../../Database/Transactions/Transaction as TransactionFile

#Message object.
import MessageObj

#SketchyBlock object.
import SketchyBlockObj

#SerializeCommon standard lib.
import ../Serialize/SerializeCommon

#Chronos external lib.
import chronos

#Sets standard lib.
import sets

type
  SyncRequest* = ref object of RootObj
    msg*: Message

  PeersSyncRequest* = ref object of SyncRequest
    remaining*: int
    existing*: HashSet[string]
    pending*: seq[tuple[ip: string, port: int]]
    result*: Future[seq[tuple[ip: string, port: int]]]

  BlockListSyncRequest* = ref object of SyncRequest
    check*: bool
    result*: Future[seq[Hash[256]]]

  TransactionSyncRequest* = ref object of SyncRequest
    check*: Hash[256]
    result*: Future[Transaction]

  BlockHeaderSyncRequest* = ref object of SyncRequest
    check*: Hash[256]
    result*: Future[BlockHeader]

  BlockBodySyncRequest* = ref object of SyncRequest
    check*: Hash[256]
    result*: Future[SketchyBlockBody]

  SketchHashesSyncRequest* = ref object of SyncRequest
    check*: Hash[256]
    result*: Future[seq[uint64]]

  SketchHashSyncRequests* = ref object of SyncRequest
    check*: tuple[salt: string, sketchHashes: seq[uint64]]
    result*: Future[seq[VerificationPacket]]

proc newPeersSyncRequest*(
  future: Future[seq[tuple[ip: string, port: int]]],
  remaining: int
): PeersSyncRequest {.inline, forceCheck: [].} =
  PeersSyncRequest(
    msg: newMessage(MessageType.PeersRequest),
    remaining: remaining,
    existing: initHashSet[string](),
    result: future
  )

proc newBlockListSyncRequest*(
  future: Future[seq[Hash[256]]],
  forwards: bool,
  amount: int,
  hash: Hash[256]
): BlockListSyncRequest {.inline, forceCheck: [].} =
  BlockListSyncRequest(
    msg: newMessage(
      MessageType.BlockListRequest,
      (if forwards: char(1) else: char(0)) &
      char(amount - 1) &
      hash.serialize()
    ),
    result: future
  )

proc newTransactionSyncRequest*(
  future: Future[Transaction],
  hash: Hash[256]
): TransactionSyncRequest {.inline, forceCheck: [].} =
  TransactionSyncRequest(
    msg: newMessage(MessageType.TransactionRequest, hash.serialize()),
    check: hash,
    result: future
  )

proc newBlockHeaderSyncRequest*(
  future: Future[BlockHeader],
  hash: Hash[256]
): BlockHeaderSyncRequest {.inline, forceCheck: [].} =
  BlockHeaderSyncRequest(
    msg: newMessage(MessageType.BlockHeaderRequest, hash.serialize()),
    check: hash,
    result: future
  )

proc newBlockBodySyncRequest*(
  future: Future[SketchyBlockBody],
  hash: Hash[256],
  contents: Hash[256]
): BlockBodySyncRequest {.inline, forceCheck: [].} =
  BlockBodySyncRequest(
    msg: newMessage(MessageType.BlockBodyRequest, hash.serialize()),
    check: contents,
    result: future
  )

proc newSketchHashesSyncRequest*(
  future: Future[seq[uint64]],
  hash: Hash[256],
  sketchCheck: Hash[256]
): SketchHashesSyncRequest {.inline, forceCheck: [].} =
  SketchHashesSyncRequest(
    msg: newMessage(MessageType.SketchHashesRequest, hash.serialize()),
    check: sketchCheck,
    result: future
  )

proc newSketchHashSyncRequests*(
  future: Future[seq[VerificationPacket]],
  hash: Hash[256],
  salt: string,
  sketchHashes: seq[uint64]
): SketchHashSyncRequests {.forceCheck: [].} =
  result = SketchHashSyncRequests(
    msg: newMessage(
      MessageType.SketchHashRequests,
      hash.serialize() &
      sketchHashes.len.toBinary(INT_LEN)
    ),
    check: (
      salt: salt,
      sketchHashes: sketchHashes
    ),
    result: future
  )

  for sketchHash in sketchHashes:
    result.msg.message &= sketchHash.toBinary(SKETCH_HASH_LEN)
