#Include the Second file in the chain, NetworkCore.
include NetworkCore

#Tuple to define missing data.
type Gap = tuple[key: BLSPublicKey, start: int, last: int]

#Sync missing Elements from a specific Client.
proc syncElements(
    network: Network,
    id: int,
    gaps: seq[Gap]
): Future[seq[Element]] {.forceCheck: [
    SocketError,
    ClientError,
    InvalidMessageError,
    DataMissing
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

    #Ask for missing Elements.
    for gap in gaps:
        #Send the Requests.
        for nonce in gap.start .. gap.last:
            #Sync the Element.
            try:
                result.add(await client.syncElement(gap.key, nonce))
            except SocketError as e:
                fcRaise e
            except ClientError as e:
                fcRaise e
            except SyncConfigError as e:
                doAssert(false, "Client we attempted to sync a Element from wasn't configured for syncing: " & e.msg)
            except InvalidMessageError as e:
                fcRaise e
            except DataMissing as e:
                fcRaise e
            except Exception as e:
                doAssert(false, "Syncing an Element in a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Stop syncing.
    try:
        await client.stopSyncing()
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Stopping syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync a list of Transactions from a specific Client.
proc syncTransactions(
    network: Network,
    id: int,
    transactions: seq[Hash[384]]
): Future[seq[Transaction]] {.forceCheck: [
    SocketError,
    ClientError,
    InvalidMessageError,
    DataMissing
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
            result.add(await client.syncTransaction(tx))
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

#Sync a Block's Elements/Transactions.
proc sync*(
    network: Network,
    consensus: Consensus,
    newBlock: Block
) {.forceCheck: [
    DataMissing,
    ValidityConcern
], async.} =
    var
        #Variable for gaps.
        gaps: seq[Gap] = @[]
        #Every Element archived in this block.
        elements: Table[string, seq[Element]] = initTable[string, seq[Element]]()
        #Seq of missing Elements.
        missingElems: seq[Element] = @[]
        #Hashes of the Transactions mentioned in missing Elements.
        txHashes: seq[Hash[384]] = @[]
        #Transactions mentioned in missing Elements.
        transactions: seq[Transaction] = @[]

    #Calculate the Elements gaps.
    for record in newBlock.records:
        #Get the MeritHolder's height.
        var holderHeigher: int = consensus[record.key].height

        #If we're missing Elements...
        if holderHeigher <= record.nonce:
            #Add the gap.
            gaps.add((
                record.key,
                holderHeigher,
                record.nonce
            ))

        #Grab their pending elements and place it in elements.
        elements[record.key.toString()] = consensus[record.key].elements

    #Sync the missing Elements.
    if gaps.len != 0:
        #List of Clients to disconnect.
        var toDisconnect: seq[int] = @[]

        #Try syncing with every client.
        var synced: bool = false
        for client in network.clients:
            #Only sync from Clients which aren't syncing from us.
            if client.theirState == Syncing:
                continue

            try:
                missingElems = await network.syncElements(client.id, gaps)
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
            except Exception as e:
                doAssert(false, "Syncing a Block's Elements and Transactions threw an Exception despite catching all thrown Exceptions: " & e.msg)

            #If we made it through that without raising or continuing, set synced to true.
            synced = true

        #Disconnect every Client marked for disconnection.
        for id in toDisconnect:
            network.clients.disconnect(id)

        #If we tried every client and didn't sync the needed data, raise a DataMissing.
        if not synced:
            raise newException(DataMissing, "Couldn't sync all the Elements in a Block.")

    #Handle each Element.
    for elem in missingElems:
        #Add its hash to the list of elements for this holder.
        try:
            elements[elem.holder.toString()].add(elem)
        except KeyError as e:
            doAssert(false, "Couldn't add a hash to a seq in a table we recently created: " & e.msg)

        #If this is a Verification, add the Transaction hash it verifies to txHashes.
        if elem of Verification:
            txHashes.add(cast[Verification](elem).hash)

    #Check the Block's aggregate.
    if not newBlock.verify(elements):
        raise newException(ValidityConcern, "Syncing a Block which has an invalid aggregate; this may be symptomatic of a MeritRemoval.")

    #Sync the missing Transactions.
    if txHashes.len != 0:
        #Dedeuplicate the list of Transactions.
        txHashes = txHashes.deduplicate()

        #List of Clients to disconnect.
        var toDisconnect: seq[int] = @[]

        #Try syncing with every client.
        var synced: bool = false
        for client in network.clients:
            #Only sync from Clients which aren't syncing from us.
            if client.theirState == Syncing:
                continue

            try:
                transactions = await network.syncTransactions(client.id, txHashes)
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
            except Exception as e:
                doAssert(false, "Syncing a Block's Elements and Transactions threw an Exception despite catching all thrown Exceptions: " & e.msg)

            #Handle each Transaction.
            try:
                for tx in transactions:
                    #Add it.
                    case tx.descendant:
                        of TransactionType.Claim:
                            try:
                                network.mainFunctions.transactions.addClaim(cast[Claim](tx))
                            except ValueError:
                                raise newException(InvalidMessageError, "Failed to add the Claim.")
                            except DataExists:
                                continue

                        of TransactionType.Send:
                            try:
                                network.mainFunctions.transactions.addSend(cast[Send](tx))
                            except ValueError:
                                raise newException(InvalidMessageError, "Failed to add the Claim.")
                            except DataExists:
                                continue

                        of TransactionType.Data:
                            try:
                                network.mainFunctions.transactions.addData(cast[Data](tx))
                            except ValueError:
                                raise newException(InvalidMessageError, "Failed to add the Claim.")
                            except DataExists:
                                continue

                        else:
                            doAssert(false, "Synced an Transaction of an unsyncable type.")
            except InvalidMessageError:
                continue

            #If we made it through that without raising or continuing, set synced to true.
            synced = true

        #Disconnect every Client marked for disconnection.
        for id in toDisconnect:
            network.clients.disconnect(id)

        #If we tried every client and didn't sync the needed data, raise a DataMissing.
        if not synced:
            raise newException(DataMissing, "Couldn't sync all the Transactions in a Block.")

    #Since we now have every Transaction, add the Elements.
    for elem in missingElems:
        try:
            network.mainFunctions.consensus.addVerification(cast[Verification](elem))
        except ValueError as e:
            doAssert(false, "Couldn't add a synced Element from a Block, after confirming it's validity, due to a ValueError: " & e.msg)
        except IndexError as e:
            doAssert(false, "Couldn't add a synced Element from a Block, after confirming it's validity, due to a IndexError: " & e.msg)
        except DataExists:
            continue

#Sync a Block's Body.
proc sync*(
    network: Network,
    header: BlockHeader
): Future[BlockBody] {.forceCheck: [
    DataMissing
], async.} =
    var
        toDisconnect: seq[int] = @[]
        synced: bool
    for client in network.clients:
        #Only sync from Clients which aren't syncing from us.
        if client.theirState == Syncing:
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
    consensus: Consensus,
    nonce: int
): Future[Block] {.forceCheck: [
    DataMissing,
    ValidityConcern
], async.} =
    var toDisconnect: seq[int] = @[]
    for client in network.clients:
        #Only sync from Clients which aren't syncing from us.
        if client.theirState == Syncing:
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
            result = await client.syncBlock(nonce)
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
        break

    #Disconnect any Clients marked for disconnection.
    for id in toDisconnect:
        network.clients.disconnect(id)

    #Sync the Block's contents.
    try:
        await network.sync(consensus, result)
    except DataMissing as e:
        fcRaise e
    except ValidityConcern as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Syncing the data in a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)
