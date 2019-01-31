#Include the Second file in the chain, NetworkCore.
include NetworkCore

#Sync a Block's Verifications/Entries.
proc sync*(network: Network, newBlock: Block): Future[bool] {.async.} =
    #If we use the `.items` iterator, we gain two advantages.
    #The first is that since we can only directly index by ID, we don't have to track that.
    #The second is that we only run if we have a client.
    for client in network.clients:
        result = true

        #Tuple to define missing data.
        type Gap = tuple[key: string, start: uint, last: uint]

        var
            #Variable for gaps.
            gaps: seq[Gap] = @[]
            #Hashes of every Verification archived in this block.
            hashes: Table[string, seq[string]] = initTable[string, seq[string]]()
            #Seq to store the Verifications in.
            verifications: seq[Verification] = newSeq[Verification]()
            #List of verified Entries.
            entries: seq[string] = @[]

        #Make sure we have all the Verifications in the Block.
        for verifier in newBlock.verifications:
            #Get the Verifier's height.
            var verifHeight: uint = network.mainFunctions.verifications.getVerifierHeight(verifier.key)

            #If we're missing Verifications...
            if verifHeight <= verifier.nonce:
                #Add the gap.
                gaps.add((
                    verifier.key,
                    verifHeight,
                    verifier.nonce
                ))

            #Grab their pending hashes and place it in hashes.
            hashes[verifier.key] = network.mainFunctions.verifications.getPendingHashes(verifier.key, verifHeight)

        #If there are no gaps, return.
        if gaps.len == 0:
            return

        #Try block is here so if anything fails, we still send SyncingOver.
        try:
            #Send syncing.
            client.sync()

            #Ask for missing Verifications.
            for gap in gaps:
                #Send the Requests.
                for nonce in gap.start .. gap.last:
                    client.send(
                        newMessage(
                            MessageType.VerificationRequest,
                            !gap.key & !nonce.toBinary()
                        )
                    )

                    #Get the response.
                    var res: Message = await client.recv()
                    #Make sure it's a Verification.
                    if res.content != MessageType.Verification:
                        return false
                    #Parse it.
                    var verif: Verification = res.message.parseVerification()
                    #Verify it's from the correct person and has the correct nonce.
                    if verif.verifier.toString() != gap.key:
                        return false
                    if verif.nonce != nonce:
                        return false

                    #Add it to the list of Verifications.
                    verifications.add(verif)

                    #Add its hash to the list of hashes for this verifier.
                    hashes[gap.key].add(verif.hash.toString())

                    #Add the Entry it verifies to entries.
                    entries.add(verif.hash.toString())

            #Check the Block's aggregate.
            #Aggregate Infos for each Verifier.
            var agInfos: seq[ptr BLSAggregationInfo] = @[]
            #Iterate over every Verifier.
            for verifier in newBlock.verifications:
                #Aggregate Infos for this verifier.
                var verifierAgInfos: seq[ptr BLSAggregationInfo] = @[]
                #Iterate over this verifier's hashes.
                for hash in hashes[verifier.key]:
                    #Create AggregationInfos.
                    verifierAgInfos.add(cast[ptr BLSAggregationInfo](alloc0(sizeof(BLSAggregationInfo))))
                    verifierAgInfos[^1][] = newBLSAggregationInfo(newBLSPublicKey(verifier.key), hash)
                #Create the aggregate AggregateInfo for this Verifier.
                agInfos.add(cast[ptr BLSAggregationInfo](alloc0(sizeof(BLSAggregationInfo))))
                agInfos[^1][] = verifierAgInfos.aggregate()

            #Add the aggregate info to the Block's signature.
            newBlock.header.verifications.setAggregationInfo(agInfos.aggregate())
            #Verify the signature.
            if not newBlock.header.verifications.verify():
                return false

            #Download the Entries.
            #Dedeuplicate the list.
            entries = entries.deduplicate()
            #Iterate over each Entry.
            for entry in entries:
                #Send the Request.
                client.send(
                    newMessage(
                        MessageType.EntryRequest,
                        entry
                    )
                )

                #Get the response.
                var res: Message = await client.recv()
                #Add it.
                case res.content:
                    of MessageType.Claim:
                        if not network.mainFunctions.lattice.addClaim(res.message.parseClaim()):
                            return false

                    of MessageType.Send:
                        if not network.mainFunctions.lattice.addSend(res.message.parseSend()):
                            return false

                    of MessageType.Receive:
                        if not network.mainFunctions.lattice.addReceive(res.message.parseReceive()):
                            return false

                    of MessageType.Data:
                        if not network.mainFunctions.lattice.addData(res.message.parseData()):
                            return false

                    else:
                        return false

            #Since we now have every Entry, add the Verifications.
            for verif in verifications:
                #If we failed to add this (shows up as an Exception), due to a MeritRemoval, the Block won't be added.
                #That said, the aggregate proves these are valid Verifications.
                if not network.mainFunctions.verifications.addVerification(verif):
                    return false

        except:
            #If there's an issue, raise it.
            raise

        finally:
            #But finally, send SyncingOver.
            client.syncOver()

        #If we finished without any errors, return before the for loop grabs another Client.
        return

#Request a Block.
proc requestBlock*(network: Network, nonce: uint): Future[bool] {.async.} =
    for client in network.clients:
        #Start syncing.
        client.sync()

        #Get the Block.
        var requested: Block = await client.syncBlock(nonce)

        #Sync the Block.
        if not await network.sync(requested):
            return false
        #That sync will send SyncingOver for us.

        #Notify MainMerit.
        result = await network.mainFunctions.merit.addBlock(requested)

        #Return to prevent running multiple times.
        return
