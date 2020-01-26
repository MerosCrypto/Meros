#Errors standard lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Block lib.
import ../../Database/Merit/Block

#Elements lib.
import ../../Database/Consensus/Elements/Elements

#Transaction lib.
import ../../Database/Transactions/Transaction as TransactionFile

#Message object.
import MessageObj

#SerializeCommon standard lib.
import ../Serialize/SerializeCommon

#Async standard lib.
import asyncdispatch

type
    SyncRequest* = ref object of RootObj
        msg*: Message

    PeersSyncRequest* = ref object of SyncRequest
        result*: Future[seq[tuple[ip: string, port: int]]]

    BlockListSyncRequest* = ref object of SyncRequest
        result*: Future[seq[Hash[256]]]

    TransactionSyncRequest* = ref object of SyncRequest
        result*: Future[Transaction]

    BlockHeaderSyncRequest* = ref object of SyncRequest
        result*: Future[BlockHeader]

    BlockBodySyncRequest* = ref object of SyncRequest
        result*: Future[BlockBody]

    SketchHashesSyncRequest* = ref object of SyncRequest
        result*: Future[seq[uint64]]

    SketchHashSyncRequests* = ref object of SyncRequest
        result*: Future[seq[VerificationPacket]]

proc newPeersSyncRequest*(
    future: Future[seq[tuple[ip: string, port: int]]]
): PeersSyncRequest {.inline, forceCheck: [].} =
    PeersSyncRequest(
        msg: newMessage(MessageType.PeersRequest),
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
            hash.toString()
        ),
        result: future
    )

proc newTransactionSyncRequest*(
    future: Future[Transaction],
    hash: Hash[256]
): TransactionSyncRequest {.inline, forceCheck: [].} =
    TransactionSyncRequest(
        msg: newMessage(MessageType.TransactionRequest, hash.toString()),
        result: future
    )

proc newBlockHeaderSyncRequest*(
    future: Future[BlockHeader],
    hash: Hash[256]
): BlockHeaderSyncRequest {.inline, forceCheck: [].} =
    BlockHeaderSyncRequest(
        msg: newMessage(MessageType.BlockHeaderRequest, hash.toString()),
        result: future
    )

proc newBlockBodySyncRequest*(
    future: Future[BlockBody],
    hash: Hash[256]
): BlockBodySyncRequest {.inline, forceCheck: [].} =
    BlockBodySyncRequest(
        msg: newMessage(MessageType.BlockBodyRequest, hash.toString()),
        result: future
    )

proc newSketchHashesSyncRequest*(
    future: Future[seq[uint64]],
    hash: Hash[256]
): SketchHashesSyncRequest {.inline, forceCheck: [].} =
    SketchHashesSyncRequest(
        msg: newMessage(MessageType.SketchHashesRequest, hash.toString()),
        result: future
    )

proc newSketchHashSyncRequests*(
    future: Future[seq[VerificationPacket]],
    hash: Hash[256],
    sketchHashes: seq[uint64]
): SketchHashSyncRequests {.forceCheck: [].} =
    result = SketchHashSyncRequests(
        msg: newMessage(
            MessageType.SketchHashRequests,
            hash.toString() &
            sketchHashes.len.toBinary(INT_LEN)
        ),
        result: future
    )

    for sketchHash in sketchHashes:
        result.msg.message &= sketchHash.toBinary(SKETCH_HASH_LEN)
