#Include the Second file in the chain, NetworkCore.
include NetworkCore

#Tuple to define missing data.
type Gap = tuple[key: BLSPublicKey, start: int, last: int]

#Sync missing info from a specific Client.
proc sync(
    network: Network,
    id: int,
    newBlock: Block
) {.forceCheck: [
    SocketError,
    ClientError,
    InvalidMessageError,
    DataMissing,
    ValidityConcern
], async.} =
    var
        #Grab the Client.
        client: Client = network.clients[id]
        #Variable for gaps.
        gaps: seq[Gap] = @[]
        #Hashes of every Verification archived in this block.
        hashes: Table[string, seq[Hash[384]]] = initTable[string, seq[Hash[384]]]()
        #Seq to store the Verifications in.
        verifications: seq[Verification] = newSeq[Verification]()
        #List of verified Entries.
        entries: seq[Hash[384]] = @[]

    #Make sure we have all the Verifications in the Block.
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
            hashes[record.key.toString()] = network.mainFunctions.verifications.getPendingHashes(record.key, verifHeight)
        except IndexError as e:
            doAssert(false, "Couldn't grab pending hashes we've confirmed to have: " & e.msg)

    #If there are no gaps, return.
    if gaps.len == 0:
        return

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
            var verif: Verification
            try:
                verif = await client.syncVerification(gap.key, nonce)
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

            #Add it to the list of Verifications.
            verifications.add(verif)

            #Add its hash to the list of hashes for this verifier.
            try:
                hashes[gap.key.toString()].add(verif.hash)
            except KeyError as e:
                doAssert(false, "Couldn't add a hash to a seq in a table we recently created: " & e.msg)

            #Add the Entry hash it verifies to entries.
            entries.add(verif.hash)

    #Check the Block's aggregate.
    if not newBlock.verify(hashes):
        raise newException(ValidityConcern, "Syncing a Block which has an invalid aggregate; this may be symptomatic of a MeritRemoval.")

    #Download the Entries.
    #Dedeuplicate the list.
    entries = entries.deduplicate()
    #Iterate over each Entry.
    for entry in entries:
        #Sync the Entry.
        var res: SyncEntryResponse
        try:
            res = await client.syncEntry(entry)
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

        #Add it.
        case res.entry:
            of EntryType.Claim:
                try:
                    network.mainFunctions.lattice.addClaim(res.claim)
                except ValueError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Claim, as pointed out by a ValueError: " & e.msg)
                except IndexError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Claim, as pointed out by a IndexError: " & e.msg)
                except GapError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Claim, as pointed out by a GapError: " & e.msg)
                except AddressError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Claim, as pointed out by a AddressError: " & e.msg)
                except EdPublicKeyError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Claim, as pointed out by a EdPublicKeyError: " & e.msg)
                except BLSError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Claim, as pointed out by a BLSError: " & e.msg)

            of EntryType.Send:
                try:
                    network.mainFunctions.lattice.addSend(res.send)
                except ValueError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Send, as pointed out by a ValueError: " & e.msg)
                except IndexError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Send, as pointed out by a IndexError: " & e.msg)
                except GapError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Send, as pointed out by a GapError: " & e.msg)
                except AddressError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Send, as pointed out by a AddressError: " & e.msg)
                except EdPublicKeyError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Send, as pointed out by a EdPublicKeyError: " & e.msg)

            of EntryType.Receive:
                try:
                    network.mainFunctions.lattice.addReceive(res.receive)
                except ValueError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Receive, as pointed out by a ValueError: " & e.msg)
                except IndexError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Receive, as pointed out by a IndexError: " & e.msg)
                except GapError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Receive, as pointed out by a GapError: " & e.msg)
                except AddressError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Receive, as pointed out by a AddressError: " & e.msg)
                except EdPublicKeyError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Receive, as pointed out by a EdPublicKeyError: " & e.msg)

            of EntryType.Data:
                try:
                    network.mainFunctions.lattice.addData(res.data)
                except ValueError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Data, as pointed out by a ValueError: " & e.msg)
                except IndexError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Data, as pointed out by a IndexError: " & e.msg)
                except GapError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Data, as pointed out by a GapError: " & e.msg)
                except AddressError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Data, as pointed out by a AddressError: " & e.msg)
                except EdPublicKeyError as e:
                    raise newException(InvalidMessageError, "Couldn't add a synced, and parsed, Data, as pointed out by a EdPublicKeyError: " & e.msg)

            else:
                doAssert(false, "SyncEntryResponse exists for an unsyncable type.")

    #Since we now have every Entry, add the Verifications.
    for verif in verifications:
        try:
            network.mainFunctions.verifications.addVerification(verif)
        except ValueError as e:
            doAssert(false, "Couldn't add a synced Verification from a Block, after confirming it's validity, due to a ValueError: " & e.msg)
        except IndexError as e:
            doAssert(false, "Couldn't add a synced Verification from a Block, after confirming it's validity, due to a IndexError: " & e.msg)

#Sync a Block's Verifications/Entries.
proc sync*(
    network: Network,
    newBlock: Block
) {.forceCheck: [
    DataMissing,
    ValidityConcern
], async.} =
    #Try syncing with every client.
    for client in network.clients:
        try:
            await network.sync(client.id, newBlock)
        #If the Client had problems, disconnect them.
        except SocketError, ClientError:
            network.clients.disconnect(client.id)
            continue
        #If we got an unexpected message, or this Client didn't have the needed info, try another client.
        except InvalidMessageError, DataMissing:
            #Stop syncing.
            try:
                await client.stopSyncing()
            #If that failed, disconnect the Client.
            except SocketError, ClientError:
                network.clients.disconnect(client.id)
            except Exception as e:
                doAssert(false, "Stopping syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)
            continue
        #This is thrown if there's a invalid aggregate, which may be symptomatic of a Merit Removal.
        #We need to inform the higher processes to double check the Verifications DAG.
        except ValidityConcern as e:
            fcRaise e
        except Exception as e:
            doAssert(false, "Syncing a Block's Verifications and Entries threw an Exception despite catching all thrown Exceptions: " & e.msg)
        #If we made it through that without raising or continuing, return.
        return
    #If we tried every client and didn't sync the needed data, raise a DataMissing.
    #This is in an if true because Nim otherwise thinks we have unreachable code.
    if true:
        raise newException(DataMissing, "Couldn't sync all the Verifications and Entries in a Block.")

#Request a Block.
proc requestBlock*(
    network: Network,
    nonce: int
): Future[Block] {.forceCheck: [
    DataMissing,
    ValidityConcern
], async.} =
    for client in network.clients:
        #Start syncing.
        try:
            await client.startSyncing()
        except SocketError, ClientError:
            network.clients.disconnect(client.id)
            continue
        except Exception as e:
            doAssert(false, "Starting syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Get the Block.
        try:
            result = await client.syncBlock(nonce)
        except SocketError, ClientError:
            network.clients.disconnect(client.id)
            continue
        except SyncConfigError as e:
            doAssert(false, "Client we attempted to sync an Entry from wasn't configured for syncing: " & e.msg)
        except InvalidMessageError, DataMissing:
            #Stop syncing.
            try:
                await client.stopSyncing()
            #If that failed, disconnect the Client.
            except SocketError, ClientError:
                network.clients.disconnect(client.id)
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
            network.clients.disconnect(client.id)
        except Exception as e:
            doAssert(false, "Stopping syncing threw an Exception despite catching all thrown Exceptions: " & e.msg)

        #Break out of the loop.
        break

    #Sync the Block's contents.
    try:
        await network.sync(result)
    except DataMissing as e:
        fcRaise e
    except ValidityConcern as e:
        fcRaise e
    except Exception as e:
        doAssert(false, "Syncing the data in a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)
