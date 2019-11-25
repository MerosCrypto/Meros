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

#Request a Transaction.
proc requestTransaction*(
    network: Network,
    hash: Hash[384]
): Future[Transaction] {.forceCheck: [
    DataMissing
], async.} =
    var synced: bool = false
    for client in network.clients.notSyncing:
        try:
            #Start syncing.
            await client.startSyncing()

            #Get the Transaction.
            try:
                result = await client.syncTransaction(hash, Hash[384](), Hash[384]())
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
    blockHash: Hash[384],
    sketchHashes: seq[uint64],
    sketchSalt: string
): Future[seq[VerificationPacket]] {.forceCheck: [
    DataMissing
], async.} =
    var synced: bool = false
    for client in network.clients.notSyncing:
        try:
            #Start syncing.
            await client.startSyncing()

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
    hash: Hash[384]
): Future[seq[uint64]] {.forceCheck: [
    DataMissing
], async.} =
    var synced: bool = false
    for client in network.clients.notSyncing:
        try:
            #Start syncing.
            await client.startSyncing()

            #Get the SketchHash.
            try:
                result = await client.syncSketchHashes(hash)
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
): Future[Block] {.forceCheck: [
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

        #Missing Transactions.
        missingTXs: seq[Hash[384]] = @[]
        #Transactions.
        transactions: Table[Hash[384], Transaction] = initTable[Hash[384], Transaction]()

    try:
        #Try to resolve the Sketch.
        sketchResult = sketcher.merge(
            newBlock.sketch,
            newBlock.capacity,
            newBlock.data.header.significant,
            newBlock.data.header.sketchSalt
        )

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
        #Generate a Table of hashes we have in the Sketcher (which are over significance).
        var lookup: Table[uint64, bool] = initTable[uint64, bool]()
        for elem in sketcher:
            if elem.significance < int(newBlock.data.header.significant):
                continue
            lookup[sketchHash(newBlock.data.header.sketchSalt, elem.packet)] = true

        #Sync the list of sketch hashes.
        try:
            missingPackets = await network.requestSketchHashes(newBlock.data.header.hash)
        except DataMissing as e:
            fcRaise e
        except Exception as e:
            doAssert(false, "Syncing a Block's SketchHashes threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Verify the sketchCheck merkle.
        try:
            newBlock.data.header.sketchCheck.verifySketchCheck(
                newBlock.data.header.sketchSalt,
                @[],
                missingPackets
            )
        except ValueError as e:
            fcRaise e

        #Remove packets present in our sketcher.
        var m: int = 0
        while m < missingPackets.len:
            if lookup.hasKey(missingPackets[m]):
                missingPackets.del(m)
            inc(m)
    #Sketch had a collision.
    except SaltError:
        raise newException(ValueError, "Block's sketch has a collision.")

    #Sync the missing VerificationPackets.
    if missingPackets.len != 0:
        try:
            packets &= await network.requestVerificationPackets(newBlock.data.header.hash, missingPackets, newBlock.data.header.sketchSalt)
        except DataMissing as e:
            fcRaise e
        except Exception as e:
            doAssert(false, "Syncing a Block's VerificationPackets threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Verify the contents merkle.
    try:
        packets = newBlock.data.header.contents.verifyContents(
            packets,
            newBlock.data.body.elements
        )
    except ValueError as e:
        fcRaise e

    #Create the Block.
    result = newBlock.data
    result.body.packets = packets

    #Check the Block's aggregate.
    try:
        if not result.verifyAggregate(network.mainFunctions.merit.getPublicKey):
            raise newException(ValueError, "Block which has an invalid aggregate.")
    except IndexError as e:
        doAssert(false, "Passing a function which can raise an IndexError raised an IndexError: " & e.msg)

    #Find missing Transactions.
    for packet in result.body.packets:
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
    var todo: Table[Hash[384], Transaction]
    #While we still have transactions to do...
    while transactions.len > 0:
        #Clear todo.
        todo = initTable[Hash[384], Transaction]()
        #Iterate over every transaction.
        for tx in transactions.values():
            block thisTX:
                #Handle initial datas.
                var first: bool = false
                if tx of Data:
                    for i in 0 ..< 16:
                        if tx.inputs[0].hash.data[i] != 0:
                            break

                        if i == 15:
                            first = true
                            break

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

    #Add every Verification Packet.
    for packet in result.body.packets:
        #Verify the packet's significant.
        var merit: int = 0
        for holder in packet.holders:
            merit += state[holder]
        if merit < int(result.header.significant):
            raise newException(ValueError, "Block has an invalid significant.")

        network.mainFunctions.consensus.addVerificationPacket(packet)

#Request a BlockBody.
proc requestBlockBody*(
    network: Network,
    hash: Hash[384]
): Future[SketchyBlockBody] {.forceCheck: [
    DataMissing
], async.} =
    var synced: bool = false
    for client in network.clients.notSyncing:
        try:
            #Start syncing.
            await client.startSyncing()

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
    hash: Hash[384]
): Future[BlockHeader] {.forceCheck: [
    DataMissing
], async.} =
    var synced: bool = false
    for client in network.clients.notSyncing:
        try:
            #Start syncing.
            await client.startSyncing()

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
    hash: Hash[384]
): Future[seq[Hash[384]]] {.forceCheck: [
    DataMissing
], async.} =
    var synced: bool = false
    for client in network.clients.notSyncing:
        try:
            #Start syncing.
            await client.startSyncing()

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
