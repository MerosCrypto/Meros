include MainVerifications

proc mainMerit() {.forceCheck: [].} =
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
        functions.merit.getHeight = proc (): int {.forceCheck: [].} =
            merit.blockchain.height

        #Handle requests for the current Difficulty.
        functions.merit.getDifficulty = proc (): Difficulty {.forceCheck: [].} =
            merit.blockchain.difficulty

        #Handle requests for a Block.
        functions.merit.getBlock = proc (
            nonce: int
        ): Block {.forceCheck: [
            IndexError
        ].} =
            try:
                result = merit.blockchain[nonce]
            except IndexError as e:
                raise e

        #Handle full blocks.
        functions.merit.addBlock = proc (
            newBlock: Block
        ) {.forceCheck: [
            ValueError,
            IndexError,
            GapError
        ], async.} =
            #Print that we're adding the Block.
            echo "Adding a new Block. "

            #Check if we're missing previous Blocks.
            if newBlock.header.nonce > merit.blockchain.height:
                #Iterate over the missing Blocks.
                for nonce in merit.blockchain.height ..< newBlock.header.nonce:
                    #Get and test the Block.
                    try:
                        await network.requestBlock(nonce)
                    except Exception as e:
                        doAssert(false, "Couldn't request a Block needed before verifying this Block: " & e.msg)

            #Verify:
                #We have all the Verifications and Entries.
                #The signature.
            var agInfos: seq[BLSAggregationInfo] = @[]
            for record in newBlock.records:
                #Grab the Verifier.
                var verifier: Verifier = verifications[record.key]

                #Verify this isn't archiving archived Verifications.
                if record.nonce <= verifier.archived:
                    raise newException(IndexError, "Block has a VerifierRecord which archives archived Verifications.")

                #Verify the merkle.
                var merkle: Hash[384]
                try:
                    merkle = verifier.calculateMerkle(record.nonce)
                except IndexError as e:
                    raise e
                if merkle != record.merkle:
                    raise newException(ValueError, "Block has a VerifierRecord with a competing Merkle.")

                var
                    #Seq of the relevant verifications for this Verifier.
                    verifs: seq[Verification]
                    #Declare an aggregation info seq for this verifier.
                    verifierAgInfos: seq[BLSAggregationInfo] = newSeq[BLSAggregationInfo](record.nonce - verifier.archived)
                #Grab the verifications.
                try:
                    verifs = verifier[verifier.archived + 1 .. record.nonce]
                except IndexError as e:
                    raise e

                for v in 0 ..< verifs.len:
                    #Make sure the Lattice has this Entry.
                    if not lattice.lookup.hasKey(verifs[v].hash.toString()):
                        raise newException(GapError, "Block refers to missing Entries, or Entries already out of an Epoch.")

                    #Create an aggregation info for this verification.
                    try:
                        verifierAgInfos[v] = newBLSAggregationInfo(verifs[v].verifier, verifs[v].hash.toString())
                    except BLSError as e:
                        doAssert(false, "Couldn't create an AggregationInfo from a valid Verification: " & e.msg)

                #Add the Verifier's aggregation info to the seq.
                try:
                    agInfos.add(verifierAgInfos.aggregate())
                except BLSError as e:
                    doAssert(false, "Couldn't aggregate the AggregationInfos of a Verifier: " & e.msg)

            #Calculate the aggregation info.
            var agInfo: BLSAggregationInfo
            try:
                agInfo = agInfos.aggregate()
            except BLSError as e:
                doAssert(false, "Couldn't aggregate the AggregationInfos of all the Verifiers: " & e.msg)
            #Make sure that if the AgInfo is nil the Signature is as well
            if agInfo.isNil != newBlock.header.aggregate.isNil:
                raise newException(ValueError, "Block has an invalid nil signature.")

            #If it's not nil, verify the Signature.
            if agInfo != nil:
                newBlock.header.aggregate.setAggregationInfo(agInfo)
                if not newBlock.header.aggregate.verify():
                    raise newException(ValueError, "Block has an invalid signature.")


            #Add the Block to the Merit.
            var epoch: Epoch
            try:
                epoch = merit.processBlock(verifications, newBlock)
            except ValueError as e:
                raise e
            except IndexError as e:
                raise e
            except GapError as e:
                raise e

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
                var key: BLSPublicKey
                try:
                    key = newBLSPublicKey(reward.key)
                except BLSError as e:
                    doAssert(false, "Couldn't extract a key from a Reward: " & e.msg)

                try:
                    mintNonce = lattice.mint(
                        key,
                        newBN(reward.score) * newBN(50)
                    )
                except ValueError as e:
                    doAssert(false, "Minting a Block Reward failed due to a ValueError: " & e.msg)
                except IndexError as e:
                    doAssert(false, "Minting a Block Reward failed due to a IndexError: " & e.msg)
                except GapError as e:
                    doAssert(false, "Minting a Block Reward failed due to a GapError: " & e.msg)
                except AddressError as e:
                    doAssert(false, "Minting a Block Reward failed due to a AddressError: " & e.msg)
                except EdPublicKeyError as e:
                    doAssert(false, "Minting a Block Reward failed due to a EdPublicKeyError: " & e.msg)

                #If we have wallets...
                if (wallet.initiated) and (not config.miner.initiated):
                    #Check if we're the one getting the reward.
                    if config.miner.publicKey.toString() == reward.key:
                        #Claim the Reward.
                        var
                            claim: Claim
                            claimNonce: int
                        try:
                            claimNonce = lattice[wallet.address].height
                        except AddressError as e:
                            doAssert(false, "One of our Wallets (" & wallet.address & ") has an invalid Address: " & e.msg)

                        claim = newClaim(
                            mintNonce,
                            claimNonce
                        )

                        #Sign the claim.
                        try:
                            claim.sign(config.miner, wallet)
                        except ValueError as e:
                            doAssert(false, "Failed to sign a Claim for a Mint due to a ValueError: " & e.msg)
                        except AddressError as e:
                            doAssert(false, "Failed to sign a Claim for a Mint due to a AddressError: " & e.msg)
                        except BLSError as e:
                            doAssert(false, "Failed to sign a Claim for a Mint due to a BLSError: " & e.msg)
                        except SodiumError as e:
                            doAssert(false, "Failed to sign a Claim for a Mint due to a SodiumError: " & e.msg)

                        #Emit it.
                        try:
                            functions.lattice.addClaim(claim)
                        except ValueError as e:
                            doAssert(false, "Failed to add a Claim for a Mint due to a ValueError: " & e.msg)
                        except IndexError as e:
                            doAssert(false, "Failed to add a Claim for a Mint due to a IndexError: " & e.msg)
                        except GapError as e:
                            doAssert(false, "Failed to add a Claim for a Mint due to a GapError: " & e.msg)
                        except AddressError as e:
                            doAssert(false, "Failed to add a Claim for a Mint due to a AddressError: " & e.msg)
                        except EdPublicKeyError as e:
                            doAssert(false, "Failed to add a Claim for a Mint due to a EdPublicKeyError: " & e.msg)
                        except BLSError as e:
                            doAssert(false, "Failed to add a Claim for a Mint due to a BLSError: " & e.msg)

            echo "Successfully added the Block."

            #Broadcast the Block and any created Claim.
            try:
                await network.broadcast(
                    newMessage(
                        MessageType.Block,
                        newBlock.serialize()
                    )
                )

                if not claim.isNil:
                    await network.broadcast(
                        newMessage(
                            MessageType.Claim,
                            claim.serialize()
                        )
                    )
            except Exception as e:
                doAssert(false, "Couldn't broadcast the new Block/Claim: " & e.msg)
