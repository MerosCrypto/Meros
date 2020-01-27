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

#Algorithm standard lib.
import algorithm

#Async standard lib.
import asyncdispatch

#Sets standard lib.
import sets

#Table standard lib.
import tables

#String utils standard lib.
import strutils

#Sync a missing Transaction.
proc syncTransaction*(
    manager: SyncManager,
    hash: Hash[256]
): Future[Transaction] {.forceCheck: [].} =
    #Create the future.
    result = newFuture[Transaction]("syncTransaction")

    #Create the request and register it.
    var
        id: int = manager.requests.len
        request: TransactionSyncRequest = result.newTransactionSyncRequest(hash)
    manager.requests[id] = request

    #Send the request to every peer.
    for peer in manager.peers.values():
        try:
            asyncCheck peer.syncRequest(id, request.msg)
        except Exception as e:
            doAssert(false, "Couldn't send a TransactionRequest to a Peer: " & e.msg)

#Sync missing Verification Packets.
proc syncVerificationPackets*(
    manager: SyncManager,
    hash: Hash[256],
    salt: string,
    sketchHashes: seq[uint64]
): Future[seq[VerificationPacket]] {.forceCheck: [].} =
    #Create the future.
    result = newFuture[seq[VerificationPacket]]("syncVerificationPackets")

    #Create the request and register it.
    var
        id: int = manager.requests.len
        request: SketchHashSyncRequests = result.newSketchHashSyncRequests(hash, salt, sketchHashes)
    manager.requests[id] = request

    #Send the request to every peer.
    for peer in manager.peers.values():
        try:
            asyncCheck peer.syncRequest(id, request.msg)
        except Exception as e:
            doAssert(false, "Couldn't send a SketchHashSyncRequests to a Peer: " & e.msg)

#Sync missing Sketch Hashes.
proc syncSketchHashes*(
    manager: SyncManager,
    hash: Hash[256],
    sketchCheck: Hash[256]
): Future[seq[uint64]] {.forceCheck: [].} =
    #Create the future.
    result = newFuture[seq[uint64]]("syncSketchHashes")

    #Create the request and register it.
    var
        id: int = manager.requests.len
        request: SketchHashesSyncRequest = result.newSketchHashesSyncRequest(hash, sketchCheck)
    manager.requests[id] = request

    #Send the request to every peer.
    for peer in manager.peers.values():
        try:
            asyncCheck peer.syncRequest(id, request.msg)
        except Exception as e:
            doAssert(false, "Couldn't send a SketchHashesSyncRequest to a Peer: " & e.msg)

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
            raise newException(ValueError, "Our sketch had a collision.")

        #If the sketch resolved, save the found packets/missing items.
        packets = sketchResult.packets
        missingPackets = sketchResult.missing

        #Verify the sketchCheck Merkle to verify the sketch decoded properly.
        newBlock.data.header.sketchCheck.verifySketchCheck(
            newBlock.data.header.sketchSalt,
            packets,
            missingPackets
        )
    #Sketch failed to decode.
    except ValueError:
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
            missingPackets = await manager.syncSketchHashes(
                newBlock.data.header.hash,
                newBlock.data.header.sketchCheck
            )
        except DataMissing as e:
            raise e
        except Exception as e:
            doAssert(false, "Syncing a Block's SketchHashes threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Remove packets present in our sketcher.
        var m: int = 0
        while m < missingPackets.len:
            if lookup.contains(missingPackets[m]):
                missingPackets.del(m)
            inc(m)

    #Sync the missing VerificationPackets.
    if missingPackets.len != 0:
        try:
            packets &= await manager.syncVerificationPackets(newBlock.data.header.hash, newBlock.data.header.sketchSalt, missingPackets)
        except DataMissing as e:
            raise e
        except Exception as e:
            doAssert(false, "Syncing a Block's VerificationPackets threw an Exception despite catching all thrown Exceptions: " & e.msg)

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
            raise newException(ValueError, "Block has an invalid aggregate.")
    except IndexError as e:
        doAssert(false, "Passing a function which can raise an IndexError raised an IndexError: " & e.msg)

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
                transactions[tx] = await manager.syncTransaction(tx)
            except DataMissing:
                #Since we did not get this Transaction, this Block is trying to archive unknown Verification OR we just don't have a proper Peer set.
                #The first is assumed.
                raise newException(ValueError, "Block tries to archive unknown Verifications.")
            except Exception as e:
                doAssert(false, "Syncing a Transaction threw an Exception despite catching all thrown Exceptions: " & e.msg)

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
                                raise newException(ValueError, "Block includes Verifications of a Transaction which has not had all its inputs mentioned in previous blocks/this block.")

                #Handle the Transaction.
                case tx:
                    of Claim as claim:
                        try:
                            manager.functions.transactions.addClaim(claim, true)
                        except ValueError:
                            raise newException(ValueError, "Block includes Verifications of an invalid Transaction.")
                        except DataExists:
                            continue

                    of Send as send:
                        try:
                            manager.functions.transactions.addSend(send, true)
                        except ValueError:
                            raise newException(ValueError, "Block includes Verifications of an invalid Transaction.")
                        except DataExists:
                            continue

                    of Data as data:
                        try:
                            manager.functions.transactions.addData(data, true)
                        except ValueError:
                            raise newException(ValueError, "Block includes Verifications of an invalid Transaction.")
                        except DataExists:
                            continue

                    else:
                        doAssert(false, "Synced an Transaction of an unsyncable type.")

        #Panic if the queue length didn't change.
        if transactions.len == todo.len:
            doAssert(false, "Transaction queue length is unchanged.")

        #Set transactions to todo.
        transactions = todo

    #Verify the included packets.
    for packet in result[0].body.packets:
        #Verify the predecessors of every Transaction are already mentioned on the chain OR also in this Block.
        var tx: Transaction
        try:
            tx = manager.functions.transactions.getTransaction(packet.hash)
        except IndexError as e:
            doAssert(false, "Couldn't get a Transaction we're confirmed to have: " & e.msg)

        if not ((tx of Claim) or ((tx of Data) and cast[Data](tx).isFirstData)):
            for input in tx.inputs:
                try:
                    if not (manager.functions.consensus.hasArchivedPacket(input.hash) or includedTXs.contains(input.hash)):
                        raise newException(ValueError, "Block's Transactions have predecessors which have yet to be mentioned on chain.")
                except IndexError as e:
                    doAssert(false, "Couldn't get if a Transaction we're confirmed to have has an archived packet: " & e.msg)

        #Get the status.
        var status: TransactionStatus
        try:
            status = manager.functions.consensus.getStatus(packet.hash)
        except IndexError as e:
            doAssert(false, "Couldn't get the status of a Transaction we're confirmed to have: " & e.msg)

        #Verify the Transaction is still in Epochs.
        if status.merit != -1:
            raise newException(ValueError, "Block has a Transaction out of Epochs.")

        #Calculate the Merit to check the significant against.
        var merit: int = 0
        for holder in packet.holders:
            #Verify every holder in the packet has yet to be archived.
            if status.holders.contains(holder):
                #If they're in holders. they're either an archived holder or a pending holder.
                if not status.pending.holders.contains(holder):
                    raise newException(ValueError, "Block archives holders who are already archived.")

            merit += state[holder]

        #Verify significant.
        if merit < int(result[0].header.significant):
            raise newException(ValueError, "Block has an invalid significant.")

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
                #of GasPrice as gasPrice:
                #    e1Nonce = gasPrice.nonce

            case e2:
                of SendDifficulty as sendDiff:
                    e2Nonce = sendDiff.nonce
                of DataDifficulty as dataDiff:
                    e2Nonce = dataDiff.nonce
                #of GasPrice as gasPrice:
                #    e2Nonce = gasPrice.nonce

            if e1Nonce < e2Nonce: -1 else: 1
    )

    for elem in result[1]:
        if hasMR.contains(elem.holder):
            raise newException(ValueError, "Block has an Element for a Merit Holder who had a Merit Removal.")

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
                        raise newException(ValueError, "Block has an Element with an invalid nonce.")

                    inc(newNonces[sendDiff.holder])
                except KeyError:
                    doAssert(false, "Table doesn't have a value for a key we made sure we had.")

            of DataDifficulty as dataDiff:
                if not newNonces.hasKey(dataDiff.holder):
                    newNonces[dataDiff.holder] = manager.functions.consensus.getArchivedNonce(dataDiff.holder)

                try:
                    if dataDiff.nonce != newNonces[dataDiff.holder] + 1:
                        raise newException(ValueError, "Block has an Element with an invalid nonce.")

                    inc(newNonces[dataDiff.holder])
                except KeyError:
                    doAssert(false, "Table doesn't have a value for a key we made sure we had.")

            #of GasPrice as gasPrice:
            #    discard

            of MeritRemoval as mr:
                if hasElem.contains(mr.holder):
                    raise newException(ValueError, "Block has an Element for a Merit Holder who had a Merit Removal.")

                try:
                    await manager.functions.consensus.verifyUnsignedMeritRemoval(mr)
                except ValueError as e:
                    raise e
                except DataExists:
                    raise newException(ValueError, "Block has an old MeritRemoval.")
                except Exception as e:
                    doAssert(false, "Verifying a MeritRemoval threw an Exception despite catching all thrown Exceptions: " & e.msg)

        hasElem.incl(elem.holder)

#Sync a missing BlockBody.
proc syncBlockBody*(
    manager: SyncManager,
    hash: Hash[256],
    contents: Hash[256]
): Future[SketchyBlockBody] {.forceCheck: [].} =
    #Create the future.
    result = newFuture[SketchyBlockBody]("syncBlockBody")

    #Create the request and register it.
    var
        id: int = manager.requests.len
        request: BlockBodySyncRequest = result.newBlockBodySyncRequest(hash, contents)
    manager.requests[id] = request

    #Send the request to every peer.
    for peer in manager.peers.values():
        try:
            asyncCheck peer.syncRequest(id, request.msg)
        except Exception as e:
            doAssert(false, "Couldn't send a BlockBodySyncRequest to a Peer: " & e.msg)

#Sync a missing BlockHeader.
proc syncBlockHeader*(
    manager: SyncManager,
    hash: Hash[256]
): Future[BlockHeader] {.forceCheck: [].} =
    #Create the future.
    result = newFuture[BlockHeader]("syncBlockHeader")

    #Create the request and register it.
    var
        id: int = manager.requests.len
        request: BlockHeaderSyncRequest = result.newBlockHeaderSyncRequest(hash)
    manager.requests[id] = request

    #Send the request to every peer.
    for peer in manager.peers.values():
        try:
            asyncCheck peer.syncRequest(id, request.msg)
        except Exception as e:
            doAssert(false, "Couldn't send a BlockHeaderSyncRequest to a Peer: " & e.msg)

#Sync a missing BlockList.
proc syncBlockList*(
    manager: SyncManager,
    forwards: bool,
    amount: int,
    hash: Hash[256]
): Future[seq[Hash[256]]] {.forceCheck: [].} =
    #Create the future.
    result = newFuture[seq[Hash[256]]]("syncBlockList")

    #Create the request and register it.
    var
        id: int = manager.requests.len
        request: BlockListSyncRequest = result.newBlockListSyncRequest(forwards, amount, hash)
    manager.requests[id] = request

    #Send the request to every peer.
    for peer in manager.peers.values():
        try:
            asyncCheck peer.syncRequest(id, request.msg)
        except Exception as e:
            doAssert(false, "Couldn't send a BlockListSyncRequest to a Peer: " & e.msg)

#Sync peers.
proc syncPeers*(
    manager: SyncManager,
    seeds: seq[tuple[ip: string, port: int]]
): Future[seq[tuple[ip: string, port: int]]] {.forceCheck: [].} =
    return
