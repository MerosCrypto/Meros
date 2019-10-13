#Include the Second file in the chain, NetworkCore.
include NetworkCore

#Sync missing VerificationPackets from a specific Client.
proc syncVerificationPackets(
    network: Network,
    id: int,
    hash: Hash[384],
    body: BlockBody
): Future[seq[Element]] {.forceCheck: [], async.} =
    doAssert(false, "Syncing VerificationPackets for a BlockBody is not supported.")

#Sync a list of Transactions from a specific Client.
proc syncTransactions(
    network: Network,
    id: int,
    transactions: seq[Hash[384]],
    sendDiff: Hash[384],
    dataDiff: Hash[384]
): Future[seq[Transaction]] {.forceCheck: [
    SocketError,
    ClientError,
    InvalidMessageError,
    DataMissing,
    Spam
], async.} =
    result = @[]

    #Grab the Client.
    var client: Client
    try:
        client = network.clients[id]
    except IndexError as e:
        raise newException(ClientError, "Couldn't grab the client: " & e.msg)

    #Send syncing.
    try:
        await client.startSyncing()
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Starting syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Ask for missing Transactions.
    for tx in transactions:
        #Sync the Transaction.
        try:
            result.add(
                await client.syncTransaction(
                    tx,
                    sendDiff,
                    dataDiff
                )
            )
        except SocketError as e:
            fcRaise e
        except ClientError as e:
            fcRaise e
        except SyncConfigError as e:
            doAssert(false, "Client we attempted to sync an Transaction from a Client that wasn't configured for syncing: " & e.msg)
        except InvalidMessageError as e:
            fcRaise e
        except DataMissing as e:
            fcRaise e
        except Spam as e:
            fcRaise e
        except Exception as e:
            doAssert(false, "Syncing an Transaction in a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Stop syncing.
    try:
        await client.stopSyncing()
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Stopping syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync a Block's Transactions/VerificationPackets.
proc sync*(
    network: Network,
    newBlock: SketchyBlock,
    txSketcher: Sketcher[Hash[384]],
    packetsSketcher: Sketcher[VerificationPacket]
) {.forceCheck: [], async.} =
    discard """
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
            except SocketError, ClientError:
                toDisconnect.add(client.id)
                continue
            #If we got an unexpected message, or this Client didn't have the needed info, try another client.
            except InvalidMessageError, DataMissing:
                #Stop syncing.
                try:
                    await client.stopSyncing()
                #If that failed, disconnect the Client.
                except SocketError, ClientError:
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
    var
        toDisconnect: seq[int] = @[]
        synced: bool
    for client in network.clients:
        #Only sync from Clients which aren't syncing from us.
        if client.remoteSync == true:
            continue

        #Start syncing.
        try:
            await client.startSyncing()
        except SocketError, ClientError:
            toDisconnect.add(client.id)
            continue
        except Exception as e:
            doAssert(false, "Starting syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Get the BlockBody.
        try:
            result = await client.syncBlockBody(header.hash)
            synced = true
        except SocketError, ClientError:
            toDisconnect.add(client.id)
            continue
        except SyncConfigError as e:
            doAssert(false, "Client we attempted to sync a BlockBody from a Client that wasn't configured for syncing: " & e.msg)
        except InvalidMessageError, DataMissing:
            #Stop syncing.
            try:
                await client.stopSyncing()
            #If that failed, disconnect the Client.
            except SocketError, ClientError:
                toDisconnect.add(client.id)
            except Exception as e:
                doAssert(false, "Stopping syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)
            continue
        except Exception as e:
            doAssert(false, "Syncing a BlockBody threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #If we made it this far, stop syncing.
        try:
            await client.stopSyncing()
        #If that failed, disconnect the Client.
        except SocketError, ClientError:
            toDisconnect.add(client.id)
        except Exception as e:
            doAssert(false, "Stopping syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Break out of the loop.
        break

    #Disconnect any Clients marked for disconnection.
    for id in toDisconnect:
        network.clients.disconnect(id)

    if not synced:
        raise newException(DataMissing, "Couldn't sync the BlockBody for the specified BlockHeader.")

#Request a Block.
proc requestBlock*(
    network: Network,
    hash: Hash[384]
): Future[SketchyBlock] {.forceCheck: [
    DataMissing
], async.} =
    var
        toDisconnect: seq[int] = @[]
        synced: bool
    for client in network.clients:
        #Only sync from Clients which aren't syncing from us.
        if client.remoteSync == true:
            continue

        #Start syncing.
        try:
            await client.startSyncing()
        except SocketError, ClientError:
            toDisconnect.add(client.id)
            continue
        except Exception as e:
            doAssert(false, "Starting syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Get the Block.
        try:
            result = await client.syncBlock(hash)
        except SocketError, ClientError:
            toDisconnect.add(client.id)
            continue
        except SyncConfigError as e:
            doAssert(false, "Client we attempted to sync a Block from a Client that wasn't configured for syncing: " & e.msg)
        except InvalidMessageError, DataMissing:
            #Stop syncing.
            try:
                await client.stopSyncing()
            #If that failed, disconnect the Client.
            except SocketError, ClientError:
                toDisconnect.add(client.id)
            except Exception as e:
                doAssert(false, "Stopping syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)
            continue
        except Exception as e:
            doAssert(false, "Syncing a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #If we made it this far, stop syncing.
        try:
            await client.stopSyncing()
        #If that failed, disconnect the Client.
        except SocketError, ClientError:
            toDisconnect.add(client.id)
        except Exception as e:
            doAssert(false, "Stopping syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Break out of the loop.
        synced = true
        break

    #Disconnect any Clients marked for disconnection.
    for id in toDisconnect:
        network.clients.disconnect(id)

    #Make sure we synced the Block.
    if not synced:
        raise newException(DataMissing, "Couldn't sync the specified Block.")
