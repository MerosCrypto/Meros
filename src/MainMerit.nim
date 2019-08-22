include MainConsensus

proc mainMerit() {.forceCheck: [].} =
    {.gcsafe.}:
        #Create the Merit.
        merit = newMerit(
            database,
            consensus,
            params.GENESIS,
            params.BLOCK_TIME,
            params.BLOCK_DIFFICULTY,
            params.LIVE_MERIT
        )

        #Handle requests for the current height.
        functions.merit.getHeight = proc (): int {.inline, forceCheck: [].} =
            merit.blockchain.height

        #Handle requests for the current Difficulty.
        functions.merit.getDifficulty = proc (): Difficulty {.inline, forceCheck: [].} =
            merit.blockchain.difficulty

        #Handle requests for a Block.
        functions.merit.getBlockByNonce = proc (
            nonce: int
        ): Block {.forceCheck: [
            IndexError
        ].} =
            try:
                result = merit.blockchain[nonce]
            except IndexError as e:
                fcRaise e

        functions.merit.getBlockByHash = proc (
            hash: Hash[384]
        ): Block {.forceCheck: [
            IndexError
        ].} =
            try:
                result = merit.blockchain[hash]
            except IndexError as e:
                fcRaise e

        functions.merit.getTotalMerit = proc (): int {.inline, forceCheck: [].} =
            merit.state.live

        functions.merit.getLiveMerit = proc (): int {.inline, forceCheck: [].} =
            merit.state.live

        functions.merit.getMerit = proc (
            key: BLSPublicKey
        ): int {.inline, forceCheck: [].} =
            merit.state[key]

        functions.merit.isLive = proc (
            key: BLSPublicKey
        ): bool {.inline, forceCheck: [].} =
            true

        #Handle full blocks.
        functions.merit.addBlock = proc (
            newBlock: Block,
            syncing: bool = false
        ) {.forceCheck: [
            ValueError,
            IndexError,
            GapError,
            DataExists
        ], async.} =
            #Print that we're adding the Block.
            echo "Adding Block ", newBlock.header.nonce, "."

            #Check if we're missing previous Blocks.
            if newBlock.header.nonce > merit.blockchain.height:
                #Iterate over the missing Blocks.
                for nonce in merit.blockchain.height ..< newBlock.header.nonce:
                    #Get and test the Block.
                    var missingBlock: Block
                    try:
                        missingBlock = await network.requestBlock(consensus, nonce)
                    except ValueError as e:
                        fcRaise e
                    except DataMissing as e:
                        #Redefine as a GapError since a failure to sync produces a gap.
                        raise newException(GapError, e.msg)
                    except ValidityConcern as e:
                        raise newException(ValueError, e.msg)
                    except Exception as e:
                        doAssert(false, "Couldn't request a Block needed before verifying this Block, despite catching all naturally thrown Exceptions: " & e.msg)

                    try:
                        await functions.merit.addBlock(missingBlock, true)
                    except ValueError as e:
                        fcRaise e
                    except IndexError as e:
                        fcRaise e
                    except GapError as e:
                        raise newException(ValueError, e.msg)
                    except DataExists as e:
                        doAssert(false, "Couldn't add a Block in the gap before this Block because DataExists: " & e.msg)
                    except Exception as e:
                        doAssert(false, "Couldn't add a Block before this Block, despite catching all naturally thrown Exceptions: " & e.msg)

            #Sync this Block.
            try:
                await network.sync(consensus, newBlock)
            except ValueError as e:
                fcRaise e
            except DataMissing as e:
                raise newException(GapError, e.msg)
            except ValidityConcern as e:
                raise newException(ValueError, e.msg)
            except Exception as e:
                doAssert(false, "Couldn't sync this Block: " & e.msg)

            #Verify Record validity (nonce and Merkle).
            var
                removed: seq[MeritHolderRecord] = @[]
                removedIndexes: Table[string, int] = initTable[string, int]()
                notRemoved: seq[MeritHolderRecord] = @[]
            for record in newBlock.records:
                #Make sure every MeritHolder has Merit.
                if merit.state[record.key] == 0:
                    raise newException(ValueError, "Block archives Elements of a merit-less MeritHolder.")

                #Check if this holder lost their Merit.
                if consensus.malicious.hasKey(record.key.toString()):
                    try:
                        var mrArchived: bool = false
                        for i in 0 ..< consensus.malicious[record.key.toString()].len:
                            if consensus.malicious[record.key.toString()][i].merkle == record.merkle:
                                mrArchived = true
                                removed.add(record)
                                removedIndexes[record.key.toString()] = i
                                break

                        if mrArchived:
                            continue
                        else:
                            notRemoved.add(record)
                    except KeyError as e:
                        doAssert(false, "Couldn't get a MeritRemoval we know exists: " & e.msg)

                #Grab the MeritHolder.
                var holder: MeritHolder = consensus[record.key]

                #Verify this isn't archiving archived Elements.
                if record.nonce <= holder.archived:
                    raise newException(IndexError, "Block has a MeritHolderRecord which archives archived Elements.")

                #Verify the merkle.
                var merkle: Hash[384]
                try:
                    merkle = holder.calculateMerkle(record.nonce)
                except IndexError as e:
                    fcRaise e
                if merkle != record.merkle:
                    raise newException(ValueError, "Block has a MeritHolderRecord with a competing Merkle.")

            #Add the Block to the Blockchain.
            try:
                merit.processBlock(newBlock)
            except ValueError as e:
                fcRaise e
            except GapError as e:
                fcRaise e
            except DataExists as e:
                fcRaise e

            #Apply reverted actions for everyone who did not have their MeritRemovals archived.
            for notRemovee in notRemoved:
                notRemovee.reapplyPending(consensus, transactions, merit.state)

            #Save every archived MeritRemoval.
            for removee in removed:
                try:
                    consensus.archive(
                        consensus.malicious[
                            removee.key.toString()
                        ][
                            removedIndexes[removee.key.toString()]
                        ]
                    )
                except KeyError as e:
                    doAssert(false, "Couldn't get the MeritRemoval of someone who has one: " & e.msg)

            #Add the Block to the Epochs and State.
            var epoch: Epoch = merit.postProcessBlock(consensus, removed, newBlock)

            #Delete the Merit of every Malicious MeritHolder.
            for removee in removed:
                merit.state.remove(removee.key, newBlock)

            #Archive the Elements mentioned in the Block.
            consensus.archive(newBlock.records)

            #Archive the hashes handled by the popped Epoch.
            transactions.archive(consensus, epoch)

            #Calculate the rewards.
            var rewards: seq[Reward] = epoch.calculate(merit.state)

            #Create the Mints (which ends up minting a total of 50000 Meri).
            var ourMint: ref Hash[384]
            for reward in rewards:
                var key: BLSPublicKey
                try:
                    key = newBLSPublicKey(reward.key)
                except BLSError as e:
                    doAssert(false, "Couldn't extract a key from a Reward: " & e.msg)

                try:
                    var mintHash: Hash[384] = transactions.mint(
                        key,
                        reward.score * uint64(50)
                    )

                    #If we have a miner wallet, check if the mint was to us.
                    if (config.miner.initiated) and (config.miner.publicKey.toString() == reward.key):
                        ourMint = new(Hash[384])
                        ourMint[] = mintHash
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

            #Commit the DBs.
            database.commit(newBlock.nonce)

            echo "Successfully added the Block."

            if not syncing:
                #Broadcast the Block.
                functions.network.broadcast(
                    MessageType.BlockHeader,
                    newBlock.header.serialize()
                )

                #If we got a Mint...
                if not ourMint.isNil:
                    #Confirm we have a wallet.
                    if wallet.isNil:
                        echo "We got a Mint with hash ", ourMint[], ", however, we don't have a Wallet to Claim it to."
                        return

                    #Claim the Reward.
                    var claim: Claim
                    try:
                        claim = newClaim(
                            transactions[ourMint[]].hash,
                            wallet.publicKey
                        )
                    except ValueError as e:
                        doAssert(false, "Created a Claim with a Mint yet newClaim raised a ValueError: " & e.msg)
                    except IndexError as e:
                        doAssert(false, "Couldn't grab a Mint we just added: " & e.msg)

                    #Sign the claim.
                    try:
                        config.miner.sign(claim)
                    except BLSError as e:
                        doAssert(false, "Failed to sign a Claim due to a BLSError: " & e.msg)

                    #Emit it.
                    try:
                        functions.transactions.addClaim(claim)
                    except ValueError as e:
                        doAssert(false, "Failed to add a Claim due to a ValueError: " & e.msg)
                    except DataExists:
                        echo "Already added a Claim for the incoming Mint."

        functions.merit.addBlockByHeader = proc (
            header: BlockHeader
        ) {.forceCheck: [
            ValueError,
            IndexError,
            GapError,
            DataExists
        ], async.} =
            try:
                merit.blockchain.testBlockHeader(header)
            except ValueError as e:
                fcRaise e
            except GapError as e:
                fcRaise e
            except UncleBlock as e:
                raise newException(ValueError, e.msg)
            except DataExists as e:
                fcRaise e

            var body: BlockBody
            try:
                body = await network.sync(header)
            except DataMissing as e:
                raise newException(ValueError, e.msg)
            except Exception as e:
                doAssert(false, "addBlockByHeader threw an Exception despite catching all Exceptions: " & e.msg)

            try:
                await functions.merit.addBlock(
                    newBlockObj(
                        header,
                        body
                    )
                )
            except ValueError as e:
                fcRaise e
            except IndexError as e:
                fcRaise e
            except GapError as e:
                fcRaise e
            except DataExists as e:
                fcRaise e
            except Exception as e:
                doAssert(false, "addBlockByHeader threw an Exception despite catching all Exceptions: " & e.msg)
