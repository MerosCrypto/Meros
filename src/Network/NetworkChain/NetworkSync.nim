#Include the Second file in the chain, NetworkCore.
include NetworkCore

discard """
#Sync a Block's Transactions/VerificationPackets.
proc sync*(
    network: Network,
    newBlock: SketchyBlock,
    sketcher: Sketcher
) {.forceCheck: [], async.} =
    var
        #Mentioned Transactions.
        mentioned: Table[Hash[384], bool] = initTable[Hash[384], bool]()
        #Hashes of the Transactions mentioned in missing Elements.
        txHashes: seq[Hash[384]] = @[]
        #Transactions mentioned in missing Elements.
        transactions: seq[Transaction] = @[]

    #Sync the missing VerificationPackets.

    #Find missing Transactions.
    for tx in newBlock.body.transactions:
        if mentioned.hasKey(tx):
            raise newException(ValueError, "Block includes duplicate Transactions.")
        mentioned[tx] = true

        try:
            discard network.mainFunctions.transactions.getTransaction(tx)
        except IndexError:
            txHashes.add(tx)

    #Sync the missing Transactions.
    if txHashes.len != 0:
        #List of Clients to disconnect.
        var toDisconnect: seq[int] = @[]

        #Try syncing with every client.
        for client in network.clients:
            #Only sync from Clients which aren't syncing from us.
            if client.remoteSync == true:
                continue

            try:
                transactions = await network.syncTransactions(
                    client.id,
                    txHashes,
                    Hash[384](),
                    network.mainFunctions.consensus.getDataMinimumDifficulty(),
                )
            #If the Client had problems, disconnect them.
            except ClientError:
                toDisconnect.add(client.id)
                continue
            #If the Client didn't have the needed info, try another client.
            except DataMissing:
                #Stop syncing.
                try:
                    await client.stopSyncing()
                #If that failed, disconnect the Client.
                except ClientError:
                    toDisconnect.add(client.id)
                except Exception as e:
                    doAssert(false, "Stopping syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)
                continue
            except Spam:
                raise newException(ValueError, "Block includes a Data below the minimum difficulty.")
            except Exception as e:
                doAssert(false, "Syncing a Block's Transactions threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Disconnect every Client marked for disconnection.
        for id in toDisconnect:
            network.clients.disconnect(id)

        #Check if we got every Transaction.
        if transactions.len != txHashes.len:
            #Since we did not, this Block is trying to archive unknown Verification OR we just don't have a proper client set.
            #The first is assumed.
            raise newException(ValueError, "Block tries to archive unknown Verifications/we couldn't get every Transaction.")

    #Check the Block's aggregate.
    try:
        if not newBlock.verify(network.mainFunctions.merit.getPublicKey, initTable[Hash[384], VerificationPacket]()):
            raise newException(ValueError, "Block which has an invalid aggregate.")
    except IndexError as e:
        doAssert(false, "Passing a function which can raise an IndexError raised an IndexError: " & e.msg)

    #List of Transactions we have yet to process.
    var todo: seq[Transaction] = newSeq[Transaction](1)
    #While we still have transactions to do...
    while todo.len > 0:
        #Clear todo.
        todo = @[]
        #Iterate over every transaction.
        for tx in transactions:
            block thisTX:
                #Handle initial datas.
                var first: bool = true
                if tx of Data:
                    for i in 0 ..< 16:
                        if tx.inputs[0].hash.data[i] != 0:
                            first = false
                            break
                else:
                    first = false

                #Make sure we have already added every input.
                if not first:
                    for input in tx.inputs:
                        try:
                            discard network.mainFunctions.transactions.getTransaction(input.hash)
                        #This TX is missing an input.
                        except IndexError:
                            #Look for the input in the pending transactions.
                            var found: bool = false
                            for todoTX in transactions:
                                if todoTX.hash == input.hash:
                                    found = true
                            #If it's found, add it.
                            if found:
                                todo.add(tx)
                                break thisTX
                            else:
                                raise newException(ValueError, "Block includes Verifications of a Transaction which has not had all its inputs mentioned in previous blocks/this block.")

                #Handle the tx.
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
        #Set transactions to todo.
        transactions = todo
"""

#Sync a Block's Body.
proc sync*(
    network: Network,
    header: BlockHeader
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
                result = await client.syncBlockBody(header.hash)
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

    discard """
    https://github.com/nim-lang/Nim/issues/12530
        #Return if we synced the body.
        if synced:
            return

    #If we exited the loop, we failed to sync the body from every client.
    raise newException(DataMissing, "Couldn't sync the specified BlockBody.")
    """

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

        #Break if we synced the body.
        if synced:
            break

    #Raise an Exception if we failed to sync the body.
    if not synced:
        raise newException(DataMissing, "Couldn't sync the specified BlockBody.")

    discard """
    https://github.com/nim-lang/Nim/issues/12530
        #Return if we synced the header.
        if synced:
            return

    #If we exited the loop, we failed to sync the header from every client.
    raise newException(DataMissing, "Couldn't sync the specified BlockHeader.")
    """

#Request a Block List.
proc requestBlockList*(
    network: Network,
    forwards: bool,
    hash: Hash[384]
): Future[Hash[384]] {.forceCheck: [], async.} =
    discard
