#Include the Second file in the chain, NetworkCore.
include NetworkCore

#[
Once https://github.com/nim-lang/Nim/issues/12530 is fixed, the following code block can be applied to the following functions:

    #Return if we synced the body.
    if synced:
        return

#If we exited the loop, we failed to sync the body from every client.
raise newException(DataMissing, "Couldn't sync the specified BlockBody.")
]#

#Request peers.
proc requestPeers*(
    network: Network,
    seeds: seq[tuple[ip: string, port: int]]
): Future[seq[tuple[ip: string, port: int]]] {.forceCheck: [], async.} =
    if network.clients.clients.len == 0:
        return seeds

    var ips: HashSet[string] = initHashSet[string]()
    for client in network.clients.notSyncing:
        try:
            #Start syncing.
            await client.startSyncing(network.networkFunctions)

            #Request peers.
            var
                peers: seq[tuple[ip: string, port: int]] = await client.syncPeers()
                p: int = 0
            while p < peers.len:
                if ips.contains(peers[p].ip):
                    peers.del(p)
                    continue

                ips.incl(peers[p].ip)
                result.add((
                    ip: (
                        ($int(peers[p].ip[0])) & "." &
                        ($int(peers[p].ip[1])) & "." &
                        ($int(peers[p].ip[2])) & "." &
                        ($int(peers[p].ip[3]))
                    ),
                    port: peers[p].port
                ))
                inc(p)

            #Stop syncing.
            await client.stopSyncing()

            #Break if we got enough peers.
            if peers.len > 8:
                break
        except ClientError:
            network.clients.disconnect(client.id)
            continue
        except Exception as e:
            doAssert(false, "Syncing peers threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Request a Transaction.
proc requestTransaction*(
    network: Network,
    hash: Hash[256]
): Future[Transaction] {.forceCheck: [
    DataMissing
], async.} =
    var synced: bool = false
    for client in network.clients.notSyncing:
        try:
            #Start syncing.
            await client.startSyncing(network.networkFunctions)

            #Get the Transaction.
            try:
                result = await client.syncTransaction(hash, Hash[256](), Hash[256]())
                synced = true
            except DataMissing:
                discard

            #Stop syncing.
            await client.stopSyncing()
        except ClientError:
            network.clients.disconnect(client.id)
            continue
        except Exception as e:
            doAssert(false, "Syncing a Transaction threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Break if we synced the Transaction.
        if synced:
            break

    #Raise an Exception if we failed to sync the Transaction.
    if not synced:
        raise newException(DataMissing, "Couldn't sync the specified Transaction.")

#Request Verification Packets.
proc requestVerificationPackets(
    network: Network,
    blockHash: Hash[256],
    sketchHashes: seq[uint64],
    sketchSalt: string
): Future[seq[VerificationPacket]] {.forceCheck: [
    DataMissing
], async.} =
    var synced: bool = false
    for client in network.clients.notSyncing:
        try:
            #Start syncing.
            await client.startSyncing(network.networkFunctions)

            #Get the VerificationPacket.
            try:
                result = await client.syncVerificationPackets(blockHash, sketchHashes, sketchSalt)
                synced = true
            except DataMissing:
                discard

            #Stop syncing.
            await client.stopSyncing()
        except ClientError:
            network.clients.disconnect(client.id)
            continue
        except Exception as e:
            doAssert(false, "Syncing Verification Packets threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Break if we synced the Verification Packets.
        if synced:
            break

    #Raise an Exception if we failed to sync the Verification Packets.
    if not synced:
        raise newException(DataMissing, "Couldn't sync the specified Verification Packets.")

#Request Sketch Hashes.
proc requestSketchHashes(
    network: Network,
    hash: Hash[256],
    sketchCheck: Hash[256]
): Future[seq[uint64]] {.forceCheck: [
    DataMissing
], async.} =
    var synced: bool = false
    for client in network.clients.notSyncing:
        try:
            #Start syncing.
            await client.startSyncing(network.networkFunctions)

            #Get the SketchHash.
            try:
                result = await client.syncSketchHashes(hash, sketchCheck)
                synced = true
            except DataMissing:
                discard

            #Stop syncing.
            await client.stopSyncing()
        except ClientError:
            network.clients.disconnect(client.id)
            continue
        except Exception as e:
            doAssert(false, "Syncing Sketch Hashes threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Break if we synced the Sketch Hashes.
        if synced:
            break

    #Raise an Exception if we failed to sync the Sketch Hashes.
    if not synced:
        raise newException(DataMissing, "Couldn't sync the specified Sketch Hashes.")

#Sync a Block's missing Transactions/VerificationPackets.
proc sync*(
    network: Network,
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
            missingPackets = await network.requestSketchHashes(
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
            packets &= await network.requestVerificationPackets(newBlock.data.header.hash, missingPackets, newBlock.data.header.sketchSalt)
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
        if not result[0].verifyAggregate(network.mainFunctions.merit.getPublicKey):
            raise newException(ValueError, "Block has an invalid aggregate.")
    except IndexError as e:
        doAssert(false, "Passing a function which can raise an IndexError raised an IndexError: " & e.msg)

    #Find missing Transactions.
    for packet in result[0].body.packets:
        includedTXs.incl(packet.hash)
        try:
            discard network.mainFunctions.transactions.getTransaction(packet.hash)
        except IndexError:
            missingTXs.add(packet.hash)

    #Sync the missing Transactions.
    if missingTXs.len != 0:
        #Get the Transactions.
        for tx in missingTXs:
            try:
                transactions[tx] = await network.requestTransaction(tx)
            except DataMissing:
                #Since we did not get this Transaction, this Block is trying to archive unknown Verification OR we just don't have a proper client set.
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
                            discard network.mainFunctions.transactions.getTransaction(input.hash)
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
                            network.mainFunctions.transactions.addClaim(claim, true)
                        except ValueError:
                            raise newException(ValueError, "Block includes Verifications of an invalid Transaction.")
                        except DataExists:
                            continue

                    of Send as send:
                        try:
                            network.mainFunctions.transactions.addSend(send, true)
                        except ValueError:
                            raise newException(ValueError, "Block includes Verifications of an invalid Transaction.")
                        except DataExists:
                            continue

                    of Data as data:
                        try:
                            network.mainFunctions.transactions.addData(data, true)
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
            tx = network.mainFunctions.transactions.getTransaction(packet.hash)
        except IndexError as e:
            doAssert(false, "Couldn't get a Transaction we're confirmed to have: " & e.msg)

        if not ((tx of Claim) or ((tx of Data) and cast[Data](tx).isFirstData)):
            for input in tx.inputs:
                try:
                    if not (network.mainFunctions.consensus.hasArchivedPacket(input.hash) or includedTXs.contains(input.hash)):
                        raise newException(ValueError, "Block's Transactions have predecessors which have yet to be mentioned on chain.")
                except IndexError as e:
                    doAssert(false, "Couldn't get if a Transaction we're confirmed to have has an archived packet: " & e.msg)

        #Get the status.
        var status: TransactionStatus
        try:
            status = network.mainFunctions.consensus.getStatus(packet.hash)
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
                    newNonces[sendDiff.holder] = network.mainFunctions.consensus.getArchivedNonce(sendDiff.holder)

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
                    newNonces[dataDiff.holder] = network.mainFunctions.consensus.getArchivedNonce(dataDiff.holder)

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
                    await network.mainFunctions.consensus.verifyUnsignedMeritRemoval(mr)
                except ValueError as e:
                    raise e
                except DataExists:
                    raise newException(ValueError, "Block has an old MeritRemoval.")
                except Exception as e:
                    doAssert(false, "Verifying a MeritRemoval threw an Exception despite catching all thrown Exceptions: " & e.msg)

        hasElem.incl(elem.holder)

#Request a BlockBody.
proc requestBlockBody*(
    network: Network,
    hash: Hash[256]
): Future[SketchyBlockBody] {.forceCheck: [
    DataMissing
], async.} =
    var synced: bool = false
    for client in network.clients.notSyncing:
        try:
            #Start syncing.
            await client.startSyncing(network.networkFunctions)

            #Get the BlockBody.
            try:
                result = await client.syncBlockBody(hash)
                synced = true
            except DataMissing:
                discard

            #Stop syncing.
            await client.stopSyncing()
        except ClientError:
            network.clients.disconnect(client.id)
            continue
        except Exception as e:
            doAssert(false, "Syncing a BlockBody threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Break if we synced the body.
        if synced:
            break

    #Raise an Exception if we failed to sync the body.
    if not synced:
        raise newException(DataMissing, "Couldn't sync the specified BlockBody.")

#Request a BlockHeader.
proc requestBlockHeader*(
    network: Network,
    hash: Hash[256]
): Future[BlockHeader] {.forceCheck: [
    DataMissing
], async.} =
    var synced: bool = false
    for client in network.clients.notSyncing:
        try:
            #Start syncing.
            await client.startSyncing(network.networkFunctions)

            #Get the BlockHeader.
            try:
                result = await client.syncBlockHeader(hash)
                synced = true
            except DataMissing:
                discard

            #Stop syncing.
            await client.stopSyncing()
        except ClientError:
            network.clients.disconnect(client.id)
            continue
        except Exception as e:
            doAssert(false, "Syncing a BlockHeader threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Break if we synced the header.
        if synced:
            break

    #Raise an Exception if we failed to sync the header.
    if not synced:
        raise newException(DataMissing, "Couldn't sync the specified BlockHeader.")

#Request a Block List.
proc requestBlockList*(
    network: Network,
    forwards: bool,
    amount: int,
    hash: Hash[256]
): Future[seq[Hash[256]]] {.forceCheck: [
    DataMissing
], async.} =
    var synced: bool = false
    for client in network.clients.notSyncing:
        try:
            #Start syncing.
            await client.startSyncing(network.networkFunctions)

            #Get the Block List.
            try:
                result = await client.syncBlockList(forwards, amount, hash)
                synced = true
            except DataMissing:
                discard

            #Stop syncing.
            await client.stopSyncing()
        except ClientError:
            network.clients.disconnect(client.id)
            continue
        except Exception as e:
            doAssert(false, "Syncing a Block List threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Break if we synced the list.
        if synced:
            break

    #Raise an Exception if we failed to sync the list.
    if not synced:
        raise newException(DataMissing, "Couldn't sync the specified Block List.")
