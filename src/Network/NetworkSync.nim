#Include the Second file in the chain, NetworkCore.
include NetworkCore

#Tuple to define missing data.
type Gap = tuple[key: BLSPublicKey, start: int, last: int]

#Sync missing Verifications from a specific Client.
proc syncVerifications(
    network: Network,
    id: int,
    gaps: seq[Gap]
): Future[seq[Verification]] {.forceCheck: [
    SocketError,
    ClientError,
    InvalidMessageError,
    DataMissing
], async.} =
    result = @[]

    #Grab the Client.
    var client: Client = network.clients[id]

    #Send syncing.
    try:
        await client.startSyncing()
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Starting syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Ask for missing Verifications.
    for gap in gaps:
        #Send the Requests.
        for nonce in gap.start .. gap.last:
            #Sync the Verification.
            try:
                result.add(await client.syncVerification(gap.key, nonce))
            except SocketError as e:
                fcRaise e
            except ClientError as e:
                fcRaise e
            except SyncConfigError as e:
                doAssert(false, "Client we attempted to sync a Verification from wasn't configured for syncing: " & e.msg)
            except InvalidMessageError as e:
                fcRaise e
            except DataMissing as e:
                fcRaise e
            except Exception as e:
                doAssert(false, "Syncing a Verification in a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Stop syncing.
    try:
        await client.stopSyncing()
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Stopping syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync a list of Entries from a specific Client.
proc syncEntries*(
    network: Network,
    id: int,
    entries: seq[Hash[384]]
): Future[seq[SyncEntryResponse]] {.forceCheck: [
    SocketError,
    ClientError,
    InvalidMessageError,
    DataMissing
], async.} =
    result = @[]

    #Grab the Client.
    var client: Client = network.clients[id]

    #Send syncing.
    try:
        await client.startSyncing()
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Starting syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Ask for missing Entries.
    for entry in entries:
        #Sync the Entry.
        try:
            result.add(await client.syncEntry(entry))
        except SocketError as e:
            fcRaise e
        except ClientError as e:
            fcRaise e
        except SyncConfigError as e:
            doAssert(false, "Client we attempted to sync an Entry from wasn't configured for syncing: " & e.msg)
        except InvalidMessageError as e:
            fcRaise e
        except DataMissing as e:
            fcRaise e
        except Exception as e:
            doAssert(false, "Syncing an Entry in a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Stop syncing.
    try:
        await client.stopSyncing()
    except SocketError as e:
        fcRaise e
    except ClientError as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Stopping syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)

#Sync a Block's Verifications/Entries.
proc sync*(
    network: Network,
    newBlock: Block
) {.forceCheck: [
    DataMissing,
    ValidityConcern
], async.} =
    var
        #Variable for gaps.
        gaps: seq[Gap] = @[]
        #Hashes of every Verification archived in this block.
        hashes: Table[string, seq[Hash[384]]] = initTable[string, seq[Hash[384]]]()
        #Seq of missing Verifications.
        verifications: seq[Verification] = @[]
        #Hashes of the Entries mentioned in missing Verifications.
        entryHashes: seq[Hash[384]] = @[]
        #Entries mentioned in missing Verifications.
        entries: seq[SyncEntryResponse] = @[]

    #Calculate the Verifications gaps.
    for record in newBlock.records:
        #Get the Verifier's height.
        var verifHeight: int = network.mainFunctions.verifications.getVerifierHeight(record.key)

        #If we're missing Verifications...
        if verifHeight <= record.nonce:
            #Add the gap.
            gaps.add((
                record.key,
                verifHeight,
                record.nonce
            ))

        #Grab their pending hashes and place it in hashes.
        try:
            hashes[record.key.toString()] = network.mainFunctions.verifications.getPendingHashes(record.key, verifHeight - 1)
        except IndexError as e:
            doAssert(false, "Couldn't grab pending hashes we've confirmed to have: " & e.msg)

    #Sync the missing Verifications.
    if gaps.len != 0:
        #List of Clients to disconnect.
        var toDisconnect: seq[int] = @[]

        #Try syncing with every client.
        var synced: bool = false
        for client in network.clients:
            try:
                verifications = await network.syncVerifications(client.id, gaps)
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
                doAssert(false, "Syncing a Block's Verifications and Entries threw an Exception despite catching all thrown Exceptions: " & e.msg)

            #If we made it through that without raising or continuing, set synced to true.
            synced = true

        #Disconnect every Client marked for disconnection.
        for id in toDisconnect:
            network.clients.disconnect(id)

        #If we tried every client and didn't sync the needed data, raise a DataMissing.
        if not synced:
            raise newException(DataMissing, "Couldn't sync all the Verifications in a Block.")

    #Handle each Verification.
    for verif in verifications:
        #Add its hash to the list of hashes for this verifier.
        try:
            hashes[verif.verifier.toString()].add(verif.hash)
        except KeyError as e:
            doAssert(false, "Couldn't add a hash to a seq in a table we recently created: " & e.msg)

        #Add the Entry hash it verifies to entryHashes.
        entryHashes.add(verif.hash)

    #Check the Block's aggregate.
    if not newBlock.verify(hashes):
        raise newException(ValidityConcern, "Syncing a Block which has an invalid aggregate; this may be symptomatic of a MeritRemoval.")

    #Sync the missing Entries.
    if entryHashes.len != 0:
        #Dedeuplicate the list of Entries.
        entryHashes = entryHashes.deduplicate()

        #List of Clients to disconnect.
        var toDisconnect: seq[int] = @[]

        #Try syncing with every client.
        var synced: bool = false
        for client in network.clients:
            try:
                entries = await network.syncEntries(client.id, entryHashes)
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
                doAssert(false, "Syncing a Block's Verifications and Entries threw an Exception despite catching all thrown Exceptions: " & e.msg)

            #Handle each Entry.
            try:
                for entry in entries:
                    #Add it.
                    case entry.entry:
                        of EntryType.Claim:
                            try:
                                network.mainFunctions.lattice.addClaim(entry.claim)
                            except ValueError, IndexError, GapError, AddressError, EdPublicKeyError, BLSError:
                                raise newException(InvalidMessageError, "Failed to add the Claim.")

                        of EntryType.Send:
                            try:
                                network.mainFunctions.lattice.addSend(entry.send)
                            except ValueError, IndexError, GapError, AddressError, EdPublicKeyError:
                                raise newException(InvalidMessageError, "Failed to add the Claim.")

                        of EntryType.Receive:
                            try:
                                network.mainFunctions.lattice.addReceive(entry.receive)
                            except ValueError, IndexError, GapError, AddressError, EdPublicKeyError:
                                raise newException(InvalidMessageError, "Failed to add the Claim.")

                        of EntryType.Data:
                            try:
                                network.mainFunctions.lattice.addData(entry.data)
                            except ValueError, IndexError, GapError, AddressError, EdPublicKeyError:
                                raise newException(InvalidMessageError, "Failed to add the Claim.")

                        else:
                            doAssert(false, "SyncEntryResponse exists for an unsyncable type.")
            except InvalidMessageError:
                continue

            #If we made it through that without raising or continuing, set synced to true.
            synced = true

        #Disconnect every Client marked for disconnection.
        for id in toDisconnect:
            network.clients.disconnect(id)

        #If we tried every client and didn't sync the needed data, raise a DataMissing.
        if not synced:
            raise newException(DataMissing, "Couldn't sync all the Entries in a Block.")

    #Since we now have every Entry, add the Verifications.
    for verif in verifications:
        try:
            network.mainFunctions.verifications.addVerification(verif)
        except ValueError as e:
            doAssert(false, "Couldn't add a synced Verification from a Block, after confirming it's validity, due to a ValueError: " & e.msg)
        except IndexError as e:
            doAssert(false, "Couldn't add a synced Verification from a Block, after confirming it's validity, due to a IndexError: " & e.msg)
        except DataExists:
            discard

#Request a Block.
proc requestBlock*(
    network: Network,
    nonce: int
): Future[Block] {.forceCheck: [
    DataMissing,
    ValidityConcern
], async.} =
    var toDisconnect: seq[int] = @[]
    for client in network.clients:
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
            doAssert(false, "Client we attempted to sync an Entry from wasn't configured for syncing: " & e.msg)
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
        await network.sync(result)
    except DataMissing as e:
        fcRaise e
    except ValidityConcern as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Syncing the data in a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)
