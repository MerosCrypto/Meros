#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Hash lib.
import ../lib/Hash

#Sketcher lib.
import ../lib/Sketcher

#Block lib.
import ../Database/Merit/Block as BlockFile

#State lib.
import ../Database/Merit/State

#Elements lib.
import ../Database/Consensus/Elements/Elements

#TransactionStatus lib.
import ../Database/Consensus/TransactionStatus

#Transactions lib.
import ../Database/Transactions/Transactions

#Message object.
import objects/MessageObj

#SketchyBlock object.
import objects/SketchyBlockObj
export SketchyBlock

#Peer lib.
import Peer
export Peer

#SyncRequest object.
import objects/SyncRequestObj

#SyncManager object.
import objects/SyncManagerObj
export SyncManagerObj

#Chronos external lib.
import chronos

#Algorithm standard lib.
import algorithm

#Sets standard lib.
import sets

#Table standard lib.
import tables

#String utils standard lib.
import strutils

#Custom future which includes a set timeout.
type SyncFuture[T] = ref object
    manager: SyncManager
    id: int

    future: Future[T]
    timeout: int

proc newSyncFuture[T](
    manager: SyncManagerObj.SyncManager, #Fixes a resolution bug in Nim.
    id: int,
    future: Future[T],
    timeout: int
): SyncFuture[T] {.inline, forceCheck: [].} =
    SyncFuture[T](
        manager: manager,
        id: id,

        future: future,
        timeout: timeout
    )

#Await which completes the future after the timeout, raising DataMissing if the actual future had yet to complete.
proc syncAwait*[T](
    future: SyncFuture[T]
): Future[T] {.forceCheck: [
    DataMissing
], async.} =
    var timeout: Future[bool]
    try:
        timeout = withTimeout(future.future, future.timeout)
    except Exception as e:
        panic("Couldn't create a timeout for this SyncRequest: " & e.msg)

    var timedOut: bool
    try:
        timedOut = not await timeout
    except Exception as e:
        panic("Couldn't create await a timeout: " & e.msg)

    if not timedOut:
        logDebug "Sync Request resolved", id = future.id

    when T is seq[tuple[ip: string, port: int]]:
        if timedOut:
            var request: PeersSyncRequest
            try:
                request = cast[PeersSyncRequest](future.manager.requests[future.id])
            except KeyError as e:
                panic("Couldn't get a SyncRequest which timed out: " & e.msg)

            future.manager.requests.del(future.id)
            return request.pending
    else:
        if timedOut:
            logDebug "SyncRequest timed out", id = future.id
            future.manager.requests.del(future.id)
            raise newLoggedException(DataMissing, "SyncRequest timed out.")

    try:
        result = future.future.read()
    except ValueError as e:
        panic("Couldn't read the value of a completed future: " & e.msg)

#Sync a missing Transaction.
proc syncTransaction*(
    manager: SyncManager,
    hash: Hash[256]
): SyncFuture[Transaction] {.forceCheck: [].} =
    #Get an ID.
    var id: int = manager.id
    inc(manager.id)

    logDebug "Syncing Transaction", id = id, hash = hash

    #Create the future.
    result = newSyncFuture[Transaction](
        manager,
        id,
        newFuture[Transaction]("syncTransaction"),
        2000
    )

    #Create the request and register it.
    var request: TransactionSyncRequest = result.future.newTransactionSyncRequest(hash)
    manager.requests[id] = request

    #Send the request to every peer.
    for peer in manager.peers.values():
        try:
            asyncCheck peer.syncRequest(id, request.msg)
        except Exception as e:
            panic("Couldn't send a TransactionRequest to a Peer: " & e.msg)

#Sync missing Verification Packets.
proc syncVerificationPackets*(
    manager: SyncManager,
    hash: Hash[256],
    salt: string,
    sketchHashes: seq[uint64]
): SyncFuture[seq[VerificationPacket]] {.forceCheck: [].} =
    #Get an ID.
    var id: int = manager.id
    inc(manager.id)

    logDebug "Syncing Verification Packets", id = id, hash = hash

    #Create the future.
    result = newSyncFuture[seq[VerificationPacket]](
        manager,
        id,
        newFuture[seq[VerificationPacket]]("syncVerificationPackets"),
        3000
    )

    #Create the request and register it.
    var request: SketchHashSyncRequests = result.future.newSketchHashSyncRequests(hash, salt, sketchHashes)
    manager.requests[id] = request

    #Send the request to every peer.
    for peer in manager.peers.values():
        try:
            asyncCheck peer.syncRequest(id, request.msg)
        except Exception as e:
            panic("Couldn't send a SketchHashSyncRequests to a Peer: " & e.msg)

#Sync missing Sketch Hashes.
proc syncSketchHashes*(
    manager: SyncManager,
    hash: Hash[256],
    sketchCheck: Hash[256]
): SyncFuture[seq[uint64]] {.forceCheck: [].} =
    #Get an ID.
    var id: int = manager.id
    inc(manager.id)

    logDebug "Syncing Sketch Hashes", id = id, hash = hash

    #Create the future.
    result = newSyncFuture[seq[uint64]](
        manager,
        id,
        newFuture[seq[uint64]]("syncSketchHashes"),
        3000
    )

    #Create the request and register it.
    var request: SketchHashesSyncRequest = result.future.newSketchHashesSyncRequest(hash, sketchCheck)
    manager.requests[id] = request

    #Send the request to every peer.
    for peer in manager.peers.values():
        try:
            asyncCheck peer.syncRequest(id, request.msg)
        except Exception as e:
            panic("Couldn't send a SketchHashesSyncRequest to a Peer: " & e.msg)

#Sync a Block's missing Transactions/VerificationPackets.
proc sync*(
    manager: SyncManager,
    state: State,
    newBlock: SketchyBlock,
    sketcher: Sketcher
): Future[(Block, seq[BlockElement])] {.forceCheck: [
    ValueError,
    DataMissing
], async.} =
    var
        #Block's Verification Packets.
        packets: seq[VerificationPacket] = @[]
        #Missing Sketch Hashes.
        missingPackets: seq[uint64] = @[]
        #SketchResult.
        sketchResult: SketchResult

        #Transactions included in the Block.
        includedTXs: HashSet[Hash[256]] = initHashSet[Hash[256]]()

        #Missing Transactions.
        missingTXs: seq[Hash[256]] = @[]
        #Transactions.
        transactions: Table[Hash[256], Transaction] = initTable[Hash[256], Transaction]()

    try:
        #Try to resolve the Sketch.
        try:
            sketchResult = sketcher.merge(
                newBlock.sketch,
                newBlock.capacity,
                newBlock.data.header.significant,
                newBlock.data.header.sketchSalt
            )
        except SaltError:
            raise newLoggedException(ValueError, "Our sketch had a collision.")

        #If the sketch resolved, save the found packets/missing items.
        packets = sketchResult.packets
        missingPackets = sketchResult.missing

        #Verify the sketchCheck Merkle to verify the sketch decoded properly.
        newBlock.data.header.sketchCheck.verifySketchCheck(
            newBlock.data.header.sketchSalt,
            packets,
            missingPackets
        )

        logDebug "Resolved Sketch and verified Sketch Check", hash = newBlock.data.header.hash
    #Sketch failed to decode.
    except ValueError:
        logDebug "Sketch resolution failed, syncing Sketch Hashes", hash = newBlock.data.header.hash

        #Clear packets.
        packets = @[]

        #Generate a Table of hashes we have in the Sketcher (which are over significance).
        var lookup: HashSet[uint64] = initHashSet[uint64]()
        for elem in sketcher:
            if elem.significance < int(newBlock.data.header.significant):
                continue
            lookup.incl(sketchHash(newBlock.data.header.sketchSalt, elem.packet))

        #Sync the list of sketch hashes.
        try:
            missingPackets = await syncAwait manager.syncSketchHashes(
                newBlock.data.header.hash,
                newBlock.data.header.sketchCheck
            )
        except DataMissing as e:
            raise e
        except Exception as e:
            panic("Syncing a Block's SketchHashes threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Remove packets present in our sketcher.
        var m: int = 0
        while m < missingPackets.len:
            if lookup.contains(missingPackets[m]):
                missingPackets.del(m)
            inc(m)

        logDebug "Synced Sketch Hashes", hash = newBlock.data.header.hash

    #Sync the missing VerificationPackets.
    if missingPackets.len != 0:
        try:
            packets &= await syncAwait manager.syncVerificationPackets(newBlock.data.header.hash, newBlock.data.header.sketchSalt, missingPackets)
        except DataMissing as e:
            raise e
        except Exception as e:
            panic("Syncing a Block's VerificationPackets threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Verify the contents Merkle.
    try:
        packets = newBlock.data.header.contents.verifyContents(
            packets,
            newBlock.data.body.elements
        )
    except ValueError as e:
        raise e

    #Create the Block.
    result[0] = newBlock.data
    result[0].body.packets = packets

    #Check the Block's aggregate.
    try:
        if not result[0].verifyAggregate(manager.functions.merit.getPublicKey):
            raise newLoggedException(ValueError, "Block has an invalid aggregate.")
    except IndexError as e:
        panic("Passing a function which can raise an IndexError raised an IndexError: " & e.msg)

    logDebug "Verified contents and aggregate", hash = newBlock.data.header.hash

    #Find missing Transactions.
    for packet in result[0].body.packets:
        includedTXs.incl(packet.hash)
        try:
            discard manager.functions.transactions.getTransaction(packet.hash)
        except IndexError:
            missingTXs.add(packet.hash)

    #Sync the missing Transactions.
    if missingTXs.len != 0:
        #Get the Transactions.
        for tx in missingTXs:
            try:
                transactions[tx] = await syncAwait manager.syncTransaction(tx)
            except DataMissing:
                #Since we did not get this Transaction, this Block is trying to archive unknown Verification OR we just don't have a proper Peer set.
                #The first is assumed.
                raise newLoggedException(ValueError, "Block tries to archive unknown Verifications.")
            except Exception as e:
                panic("Syncing a Transaction threw an Exception despite catching all thrown Exceptions: " & e.msg)

    logDebug "Synced missing Transactions", hash = newBlock.data.header.hash

    #List of Transactions we have yet to process.
    var todo: Table[Hash[256], Transaction]
    #While we still have transactions to do...
    while transactions.len > 0:
        #Clear todo.
        todo = initTable[Hash[256], Transaction]()
        #Iterate over every transaction.
        for tx in transactions.values():
            block thisTX:
                #Handle initial Datas.
                var first: bool = (tx of Data) and (tx.inputs[0].hash == Hash[256]())

                #Make sure we have already added every input.
                if not first:
                    for input in tx.inputs:
                        try:
                            discard manager.functions.transactions.getTransaction(input.hash)
                        #This TX is missing an input.
                        except IndexError:
                            #Look for the input in the pending Transactions.
                            if transactions.hasKey(input.hash):
                                #If it's there, add this Transaction to be handled later.
                                todo[tx.hash] = tx
                                break thisTX
                            else:
                                raise newLoggedException(ValueError, "Block includes Verifications of a Transaction which has not had all its inputs mentioned in previous blocks/this block.")

                #Handle the Transaction.
                case tx:
                    of Claim as claim:
                        try:
                            manager.functions.transactions.addClaim(claim, true)
                        except ValueError:
                            raise newLoggedException(ValueError, "Block includes Verifications of an invalid Transaction.")
                        except DataExists:
                            continue

                    of Send as send:
                        try:
                            manager.functions.transactions.addSend(send, true)
                        except ValueError:
                            raise newLoggedException(ValueError, "Block includes Verifications of an invalid Transaction.")
                        except DataExists:
                            continue

                    of Data as data:
                        try:
                            manager.functions.transactions.addData(data, true)
                        except ValueError:
                            raise newLoggedException(ValueError, "Block includes Verifications of an invalid Transaction.")
                        except DataExists:
                            continue

                    else:
                        panic("Synced an Transaction of an unsyncable type.")

        #Panic if the queue length didn't change.
        if transactions.len == todo.len:
            panic("Transaction queue length is unchanged.")

        #Set transactions to todo.
        transactions = todo

    logDebug "Added missing Transactions", hash = newBlock.data.header.hash

    #Verify the included packets.
    for packet in result[0].body.packets:
        #Verify the predecessors of every Transaction are already mentioned on the chain OR also in this Block.
        var tx: Transaction
        try:
            tx = manager.functions.transactions.getTransaction(packet.hash)
        except IndexError as e:
            panic("Couldn't get a Transaction we're confirmed to have: " & e.msg)

        if not ((tx of Claim) or ((tx of Data) and cast[Data](tx).isFirstData)):
            for input in tx.inputs:
                try:
                    if not (manager.functions.consensus.hasArchivedPacket(input.hash) or includedTXs.contains(input.hash)):
                        raise newLoggedException(ValueError, "Block's Transactions have predecessors which have yet to be mentioned on chain.")
                except IndexError as e:
                    panic("Couldn't get if a Transaction we're confirmed to have has an archived packet: " & e.msg)

        #Get the status.
        var status: TransactionStatus
        try:
            status = manager.functions.consensus.getStatus(packet.hash)
        except IndexError as e:
            panic("Couldn't get the status of a Transaction we're confirmed to have: " & e.msg)

        #Verify the Transaction is still in Epochs.
        if status.merit != -1:
            raise newLoggedException(ValueError, "Block has a Transaction out of Epochs.")

        #Calculate the Merit to check the significant against.
        var merit: int = 0
        for holder in packet.holders:
            #Verify every holder in the packet has yet to be archived.
            if status.holders.contains(holder):
                #If they're in holders. they're either an archived holder or a pending holder.
                if not status.packet.holders.contains(holder):
                    raise newLoggedException(ValueError, "Block archives holders who are already archived.")

            merit += state[holder, status.epoch]

        #Verify significant.
        if merit < int(result[0].header.significant):
            raise newLoggedException(ValueError, "Block has an invalid significant.")

    #Verify the included Elements.
    result[1] = result[0].body.elements
    var
        newNonces: Table[uint16, int] = initTable[uint16, int]()
        hasElem: set[uint16] = {}
        hasMR: set[uint16] = {}
    #Sort by nonce so we don't risk a gap.
    result[1].sort(
        proc (
            e1: BlockElement,
            e2: BlockElement
        ): int {.forceCheck: [].} =
            var e1Nonce: int = -1
            var e2Nonce: int = -1

            case e1:
                of SendDifficulty as sendDiff:
                    e1Nonce = sendDiff.nonce
                of DataDifficulty as dataDiff:
                    e1Nonce = dataDiff.nonce
                #of GasDifficulty as gasDiff:
                #    e1Nonce = gasDiff.nonce

            case e2:
                of SendDifficulty as sendDiff:
                    e2Nonce = sendDiff.nonce
                of DataDifficulty as dataDiff:
                    e2Nonce = dataDiff.nonce
                #of GasDifficulty as gasDiff:
                #    e2Nonce = gasDiff.nonce

            if e1Nonce < e2Nonce: -1 else: 1
    )

    for elem in result[1]:
        if hasMR.contains(elem.holder):
            raise newLoggedException(ValueError, "Block has an Element for a Merit Holder who had a Merit Removal.")

        case elem:
            of SendDifficulty as sendDiff:
                if not newNonces.hasKey(sendDiff.holder):
                    newNonces[sendDiff.holder] = manager.functions.consensus.getArchivedNonce(sendDiff.holder)

                try:
                    if sendDiff.nonce != newNonces[sendDiff.holder] + 1:
                        #[
                        Ideally, we'd now check if this was an existing Element or a conflicting Element.
                        Unfortunately, MeritRemovals require the second Element to have an independent signature.
                        The Block's aggregate signature won't work as a proof.
                        So even though we can know there's a malicious Merit Holder, we can't tell the network.
                        If we then acted on this knowledge, we'd risk desyncing.
                        Therefore, we have to just reject the Block for being invalid.
                        ]#
                        raise newLoggedException(ValueError, "Block has an Element with an invalid nonce.")

                    inc(newNonces[sendDiff.holder])
                except KeyError:
                    panic("Table doesn't have a value for a key we made sure we had.")

            of DataDifficulty as dataDiff:
                if not newNonces.hasKey(dataDiff.holder):
                    newNonces[dataDiff.holder] = manager.functions.consensus.getArchivedNonce(dataDiff.holder)

                try:
                    if dataDiff.nonce != newNonces[dataDiff.holder] + 1:
                        raise newLoggedException(ValueError, "Block has an Element with an invalid nonce.")

                    inc(newNonces[dataDiff.holder])
                except KeyError:
                    panic("Table doesn't have a value for a key we made sure we had.")

            #of GasDifficulty as gasDiff:
            #    discard

            of MeritRemoval as mr:
                if hasElem.contains(mr.holder):
                    raise newLoggedException(ValueError, "Block has an Element for a Merit Holder who had a Merit Removal.")

                try:
                    await manager.functions.consensus.verifyUnsignedMeritRemoval(mr)
                except ValueError as e:
                    raise e
                except DataExists:
                    raise newLoggedException(ValueError, "Block has an old MeritRemoval.")
                except Exception as e:
                    panic("Verifying a MeritRemoval threw an Exception despite catching all thrown Exceptions: " & e.msg)

        hasElem.incl(elem.holder)

#Sync a missing BlockBody.
proc syncBlockBody*(
    manager: SyncManager,
    hash: Hash[256],
    contents: Hash[256]
): SyncFuture[SketchyBlockBody] {.forceCheck: [].} =
    #Get an ID.
    var id: int = manager.id
    inc(manager.id)

    logDebug "Syncing Block Body", id = id, hash = hash

    #Create the future.
    result = newSyncFuture[SketchyBlockBody](
        manager,
        id,
        newFuture[SketchyBlockBody]("syncBlockBody"),
        5000
    )

    #Create the request and register it.
    var request: BlockBodySyncRequest = result.future.newBlockBodySyncRequest(hash, contents)
    manager.requests[id] = request

    #Send the request to every peer.
    for peer in manager.peers.values():
        try:
            asyncCheck peer.syncRequest(id, request.msg)
        except Exception as e:
            panic("Couldn't send a BlockBodySyncRequest to a Peer: " & e.msg)

#Sync a missing BlockHeader.
proc syncBlockHeader*(
    manager: SyncManager,
    hash: Hash[256]
): SyncFuture[BlockHeader] {.forceCheck: [].} =
    #Get an ID.
    var id: int = manager.id
    inc(manager.id)

    logDebug "Syncing Block Header", id = id, hash = hash

    #Create the future.
    result = newSyncFuture[BlockHeader](
        manager,
        id,
        newFuture[BlockHeader]("syncBlockHeader"),
        5000
    )

    #Create the request and register it.
    var request: BlockHeaderSyncRequest = result.future.newBlockHeaderSyncRequest(hash)
    manager.requests[id] = request

    #Send the request to every peer.
    for peer in manager.peers.values():
        try:
            asyncCheck peer.syncRequest(id, request.msg)
        except Exception as e:
            panic("Couldn't send a BlockHeaderSyncRequest to a Peer: " & e.msg)

#Sync a missing BlockList.
proc syncBlockList*(
    manager: SyncManager,
    forwards: bool,
    amount: int,
    hash: Hash[256]
): SyncFuture[seq[Hash[256]]] {.forceCheck: [].} =
    #Get an ID.
    var id: int = manager.id
    inc(manager.id)

    logDebug "Syncing Block List", id = id, forwards = forwards, amount = amount

    #Create the future.
    result = newSyncFuture[seq[Hash[256]]](
        manager,
        id,
        newFuture[seq[Hash[256]]]("syncBlockList"),
        3000
    )

    #Create the request and register it.
    var request: BlockListSyncRequest = result.future.newBlockListSyncRequest(forwards, amount, hash)
    manager.requests[id] = request

    #Send the request to every peer.
    for peer in manager.peers.values():
        try:
            asyncCheck peer.syncRequest(id, request.msg)
        except Exception as e:
            panic("Couldn't send a BlockListSyncRequest to a Peer: " & e.msg)

#Sync peers.
proc syncPeers*(
    manager: SyncManager,
    seeds: seq[tuple[ip: string, port: int]]
): SyncFuture[seq[tuple[ip: string, port: int]]] {.forceCheck: [].} =
    #Get an ID.
    var id: int = manager.id
    inc(manager.id)

    logDebug "Syncing Peers", id = id

    if manager.peers.len == 0:
        result = newSyncFuture[seq[tuple[ip: string, port: int]]](
            manager,
            0,
            newFuture[seq[tuple[ip: string, port: int]]]("syncPeers"),
            3000
        )
        try:
            result.future.complete(seeds)
        except Exception as e:
            panic("Failed to complete a future: " & e.msg)
        return

    #Create the future.
    result = newSyncFuture[seq[tuple[ip: string, port: int]]](
        manager,
        id,
        newFuture[seq[tuple[ip: string, port: int]]]("syncPeers"),
        3000
    )

    #Create the request and register it.
    var request: PeersSyncRequest = result.future.newPeersSyncRequest(manager.peers.len)
    manager.requests[id] = request

    #Send the request to every peer.
    for peer in manager.peers.values():
        try:
            asyncCheck peer.syncRequest(id, request.msg)
        except Exception as e:
            panic("Couldn't send a BlockListSyncRequest to a Peer: " & e.msg)
