include MainVerifications

proc mainMerit() {.raises: [].} =
    {.gcsafe.}:
        #Create the Merit.
        merit = newMerit(
            functions.database,
            verifications,
            GENESIS,
            BLOCK_TIME,
            BLOCK_DIFFICULTY,
            LIVE_MERIT
        )

        #Handle requests for the current height.
        functions.merit.getHeight = proc (): int {.raises: [].} =
            merit.blockchain.height

        #Handle requests for the current Difficulty.
        functions.merit.getDifficulty = proc (): Difficulty {.raises: [].} =
            merit.blockchain.difficulty

        #Handle requests for a Block.
        functions.merit.getBlock = proc (
            nonce: int
        ): Block {.raises: [
            IndexError
        ].} =
            merit.blockchain[nonce]

        #Handle full blocks.
        functions.merit.addBlock = proc (
            newBlock: Block
        ): Future[bool] {.async.} =
            result = true

            #Print that we're adding the Block.
            echo "Adding a new Block. "

            #If we're connected to other people, sync missing info.
            if network.clients.clients.len > 0:
                #Check if we're missing previous Blocks.
                if newBlock.header.nonce > merit.blockchain.height:
                    #Iterate over the missing Blocks.
                    for nonce in merit.blockchain.height ..< newBlock.header.nonce:
                        #Get and test the Block.
                        try:
                            if not await network.requestBlock(nonce):
                                raise newException(Exception, "")
                        except:
                            echo "Failed to add the Block."
                            return false

                #Missing Verifications/Entries.
                if not await network.sync(newBlock):
                    echo "Failed to add the Block."
                    return false

            if newBlock.records.len > 0:
                #Verify we have all the Verifications and Entries, as well as verify the signature.
                var
                    agInfos: seq[BLSAggregationInfo] = @[]
                    verifiers: Table[string, bool] = initTable[string, bool]()
                for index in newBlock.records:
                    #Verify this isn't archiving archived Verifications.
                    if index.nonce < verifications[index.key].archived:
                        echo "Failed to add the Block."
                        return false

                    #Verify we have all the Verifications.
                    if index.nonce >= verifications[index.key].height:
                        echo "Failed to add the Block."
                        return false

                    #Check the merkle.
                    if verifications[index.key].calculateMerkle(index.nonce) != index.merkle:
                        echo "Failed to add the Block."
                        return false

                    #Verify this Block doesn't have this verifier twice,
                    if verifiers.hasKey(index.key.toString()):
                        echo "Failed to add the Block."
                        return false
                    verifiers[index.key.toString()] = true

                    var
                        #Start of this verifier's unarchived verifications.
                        verifierStart: int = verifications[index.key].verifications[0].nonce
                        #Grab this Verifier's verifications.
                        verifierVerifs: seq[Verification] = verifications[index.key][verifierStart .. index.nonce]
                        #Declare an aggregation info seq for this verifier.
                        verifierAgInfos: seq[BLSAggregationInfo] = newSeq[BLSAggregationInfo](verifierVerifs.len)
                    for v in 0 ..< verifierVerifs.len:
                        #Make sure the Lattice has this Entry.
                        if not lattice.lookup.hasKey(verifierVerifs[v].hash.toString()):
                            echo "Failed to add the Block."
                            return false

                        #Create an aggregation info for this verification.
                        verifierAgInfos[v] = newBLSAggregationInfo(verifierVerifs[v].verifier, verifierVerifs[v].hash.toString())

                    #Add the Verifier's aggregation info to the seq.
                    agInfos.add(verifierAgInfos.aggregate())

                #Calculate the aggregation info.
                var agInfo: BLSAggregationInfo = agInfos.aggregate()
                #Make sure that if the AgInfo is nil the Signature is as well
                if agInfo.isNil != newBlock.header.aggregate.isNil:
                    echo "Failed to add the Block."
                    return false
                #If it's not nil, verify the Signature.
                if agInfo != nil:
                    newBlock.header.aggregate.setAggregationInfo(agInfo)
                    if not newBlock.header.aggregate.verify():
                        echo "Failed to add the Block."
                        return false

            #Add the Block to the Merit.
            var epoch: Epoch
            try:
                epoch = merit.processBlock(verifications, newBlock)
            except:
                echo "Failed to add the Block."
                return false

            #Archive the Verifications mentioned in the Block.
            verifications.archive(newBlock.records)

            #Archive the hashes handled by the popped Epoch.
            lattice.archive(epoch)

            #Calculate the rewards.
            var rewards: Rewards = epoch.calculate(merit.state)

            #Create the Mints (which ends up minting a total of 50000 MR).
            var
                #Nonce of the Mint.
                mintNonce: int
                #Any Claim we may create.
                claim: Claim
            for reward in rewards:
                mintNonce = lattice.mint(
                    reward.key,
                    newBN(reward.score) * newBN(50) #This is a BN because 50 will end up as a much bigger number (decimals).
                )

                #If we have wallets...
                if (wallet.initiated) and (not config.miner.initiated):
                    #Check if we're the one getting the reward.
                    if config.miner.publicKey.toString() == reward.key:
                        #Claim the Reward.
                        var claim: Claim = newClaim(
                            mintNonce,
                            lattice[wallet.address].height
                        )
                        #Sign the claim.
                        claim.sign(config.miner, wallet)

                        #Emit it.
                        try:
                            functions.lattice.addClaim(claim)
                        except:
                            raise newException(EventError, "Couldn't get and call lattice.claim.")

            echo "Successfully added the Block."

            #Broadcast the Block.
            await network.broadcast(
                newMessage(
                    MessageType.Block,
                    newBlock.serialize()
                )
            )

            #If we made a Claim...
            if not claim.initiated:
                #Broadcast the Claim.
                await network.broadcast(
                    newMessage(
                        MessageType.Claim,
                        claim.serialize()
                    )
                )
