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
                fcRaise e

        #Handle full blocks.
        functions.merit.addBlock = proc (
            newBlock: Block
        ) {.forceCheck: [
            ValueError,
            IndexError,
            GapError
        ], async.} =
            #If we already have this Block, raise.
            if newBlock.header.nonce < merit.blockchain.height:
                raise newException(IndexError, "Block already added.")

            #Print that we're adding the Block.
            echo "Adding Block ", newBlock.header.nonce, "."

            #Check if we're missing previous Blocks.
            if newBlock.header.nonce > merit.blockchain.height:
                #Iterate over the missing Blocks.
                for nonce in merit.blockchain.height ..< newBlock.header.nonce:
                    #Get and test the Block.
                    try:
                        await functions.merit.addBlock(await network.requestBlock(nonce))
                    #Redefine as a GapError since a failure to sync produces a gap.
                    except DataMissing as e:
                        raise newException(GapError, e.msg)
                    except ValidityConcern as e:
                        raise newException(ValueError, e.msg)
                    except Exception as e:
                        doAssert(false, "Couldn't request and add a Block needed before verifying this Block: " & e.msg)

            #Sync this Block.
            try:
                await network.sync(newBlock)
            except DataMissing as e:
                raise newException(GapError, e.msg)
            except ValidityConcern as e:
                raise newException(ValueError, e.msg)
            except Exception as e:
                doAssert(false, "Couldn't sync this Block: " & e.msg)

            #Verify Record validity (nonce and Merkle), as well as whether or not the verified Entries are out of Epochs yet.
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
                    fcRaise e
                if merkle != record.merkle:
                    raise newException(ValueError, "Block has a VerifierRecord with a competing Merkle.")

                #Seq of the relevant verifications for this Verifier.
                var verifs: seq[Verification]
                #Grab the verifications.
                try:
                    verifs = verifier[verifier.archived + 1 .. record.nonce]
                except IndexError as e:
                    fcRaise e

                #Make sure the Lattice has the verified Entries.
                for v in 0 ..< verifs.len:
                    if not lattice.lookup.hasKey(verifs[v].hash.toString()):
                        raise newException(GapError, "Block refers to missing Entries, or Entries already out of an Epoch.")

            #Add the Block to the Merit.
            var epoch: Epoch
            try:
                epoch = merit.processBlock(verifications, newBlock)
            except ValueError as e:
                fcRaise e
            except IndexError as e:
                fcRaise e
            except GapError as e:
                fcRaise e

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
                if wallet.initiated and config.miner.initiated:
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
