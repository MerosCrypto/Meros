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
        #Get the MeritHolder.
        var holder: MeritHolder = consensus[record.key]

        #If we're missing Elements...
        if holder.height <= record.nonce:
            #Add the gap.
            gaps.add((
                record.key,
                holder.height,
                record.nonce
            ))

        #Grab their pending elements and place it in elements.
        elements[record.key.toString()] = newSeq[Element](holder.height - holder.archived - 1)
        for e in holder.archived + 1 ..< holder.height:
            try:
                elements[record.key.toString()][e - (holder.archived + 1)] = holder[e]
            except KeyError as e:
                doAssert(false, "Couldn't access a seq in a table we just created: " & e.msg)
            except IndexError as e:
                doAssert(false, "Couldn't get an Element by it's index despite looping up to the Merit Holder's height: " & e.msg)

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

    #Add the Elements since we know they're valid.
    for elem in missingElems:
        case elem:
            of Verification as verif:
                try:
                    network.mainFunctions.consensus.addVerification(verif)
                except ValueError as e:
                    doAssert(false, "Couldn't add a synced Verification from a Block, after confirming it's validity, due to a ValueError: " & e.msg)
                except DataExists:
                    continue

            of MeritRemoval as mr:
                network.mainFunctions.consensus.addMeritRemoval(mr)

    #Sync the missing Transactions.
    if txHashes.len != 0:
        #Dedeuplicate the list of Transactions.
        txHashes = txHashes.deduplicate()

        #List of Clients to disconnect.
        var toDisconnect: seq[int] = @[]

        #Try syncing with every client.
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

        #Disconnect every Client marked for disconnection.
        for id in toDisconnect:
            network.clients.disconnect(id)

        discard """
        We are not confirmed to have every Transaction in this Block.
        If the middle TX hash is invalid, every Client will fail in the middle.
        The neccessary thing to do is use gap-syncing to get the needed Transactions we didn't sync.
        That said, we can make this better by having syncTransactions try to get every Transaction from the Client, returning whatever it successfully grabbed.
        """

        #List of Transactions we have yet to process.
        var todo: seq[Transaction] = newSeq[Transaction](1)
        #While we still have transactions to do...
        while todo.len > 0:
            #Clear todo.
            todo = @[]
            #Iterate over every transaction.
            for tx in transactions:
                block thisTX:
                    #Make sure we have already added every input.
                    for input in tx.inputs:
                        try:
                            #If the TX doesn't exist, this will throw. If it does exist but isn't verified, throw a different error.
                            if not network.mainFunctions.transactions.getTransaction(input.hash).verified:
                                raise newException(ValueError, "")
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
                        #This TX spends an unconfirmed input.
                        except ValueError:
                            break thisTX

                    #Handle the tx.
                    case tx:
                        of Claim as claim:
                            try:
                                network.mainFunctions.transactions.addClaim(claim, true)
                            except ValueError:
                                discard """
                                    Whoever sent us this Transaction should be penalized.
                                    We should try again from a different client.
                                    This is coded like this because:
                                        - The Verification mentioning this hash may be 'unknown'.
                                        - A malicious node may have sent this an invalid TX with that hash to mess with us.
                                        - Even if the verified TX is invalid, the Block as a whole is valid.
                                """
                            except DataExists:
                                continue

                        of Send as send:
                            try:
                                network.mainFunctions.transactions.addSend(send, true)
                            except ValueError:
                                discard """
                                    Whoever sent us this Transaction should be penalized.
                                    We should try again from a different client.
                                    This is coded like this because:
                                        - The Verification mentioning this hash may be 'unknown'.
                                        - A malicious node may have sent this an invalid TX with that hash to mess with us.
                                        - Even if the verified TX is invalid, the Block as a whole is valid.
                                """
                            except DataExists:
                                continue

                        of Data as data:
                            try:
                                network.mainFunctions.transactions.addData(data, true)
                            except ValueError:
                                discard """
                                    Whoever sent us this Transaction should be penalized.
                                    We should try again from a different client.
                                    This is coded like this because:
                                        - The Verification mentioning this hash may be 'unknown'.
                                        - A malicious node may have sent this an invalid TX with that hash to mess with us.
                                        - Even if the verified TX is invalid, the Block as a whole is valid.
                                """
                            except DataExists:
                                continue

                        else:
                            doAssert(false, "Synced an Transaction of an unsyncable type.")
            #Set transactions to todo.
            transactions = todo

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
        synced = true
        break

    #Disconnect any Clients marked for disconnection.
    for id in toDisconnect:
        network.clients.disconnect(id)

    #Make sure we synced the Block.
    if not synced:
        raise newException(DataMissing, "Couldn't sync the specified BlockHeader.")

    #Sync the Block's contents.
    try:
        await network.sync(consensus, result)
    except DataMissing as e:
        fcRaise e
    except ValidityConcern as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Syncing the data in a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)
