include MainConsensus

proc mainMerit() {.forceCheck: [].} =
    {.gcsafe.}:
        #Create the Merit.
        merit = newMerit(
            database,
            consensus,
            GENESIS,
            BLOCK_TIME,
            BLOCK_DIFFICULTY,
            LIVE_MERIT
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
            #If we already have this Block, raise.
            #This is a needed check, even though there's the same one in processBlock, because requested Blocks are rebroadcasted.
            #If a Client send us a back a Block, and we try to sync it, while they're still syncing, there's a standoff.
            if newBlock.header.nonce < merit.blockchain.height:
                raise newException(DataExists, "Block already added.")

            #Print that we're adding the Block.
            echo "Adding Block ", newBlock.header.nonce, "."

            #Check if we're missing previous Blocks.
            if newBlock.header.nonce > merit.blockchain.height:
                #Iterate over the missing Blocks.
                for nonce in merit.blockchain.height ..< newBlock.header.nonce:
                    #Get and test the Block.
                    try:
                        await functions.merit.addBlock(await network.requestBlock(consensus, nonce), true)
                    #Redefine as a GapError since a failure to sync produces a gap.
                    except DataMissing as e:
                        raise newException(GapError, e.msg)
                    except ValidityConcern as e:
                        raise newException(ValueError, e.msg)
                    except ValueError as e:
                        fcRaise e
                    except IndexError as e:
                        fcRaise e
                    except GapError as e:
                        raise newException(ValueError, e.msg)
                    except DataExists as e:
                        doAssert(false, "Couldn't add a Block in the gap before this Block because DataExists: " & e.msg)
                    except Exception as e:
                        doAssert(false, "Couldn't request and add a Block needed before verifying this Block, despite catching all naturally thrown Exceptions: " & e.msg)

            #Sync this Block.
            try:
                await network.sync(consensus, newBlock)
            except DataMissing as e:
                raise newException(GapError, e.msg)
            except ValidityConcern as e:
                raise newException(ValueError, e.msg)
            except Exception as e:
                doAssert(false, "Couldn't sync this Block: " & e.msg)

            #Verify Record validity (nonce and Merkle), as well as whether or not the verified Transactions are out of Epochs yet.
            for record in newBlock.records:
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

                #Seq of the relevant Elements for this MeritHolder.
                var elems: seq[Element]
                #Grab the consensus.
                try:
                    elems = holder[holder.archived + 1 .. record.nonce]
                except IndexError as e:
                    fcRaise e

                #Make sure Transactions has the verified Transactions.
                for e in 0 ..< elems.len:
                    if elems[e] of Verification:
                        try:
                            discard transactions[cast[Verification](elems[e]).hash]
                        except IndexError:
                            raise newException(GapError, "Block refers to missing Transactions.")

            #Add the Block to the Merit.
            var epoch: Epoch
            try:
                epoch = merit.processBlock(consensus, newBlock)
            except ValueError as e:
                fcRaise e
            except GapError as e:
                fcRaise e
            except DataExists as e:
                fcRaise e

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
                    if not wallet.initiated:
                        echo "We got a Mint with hash ", ourMint[], ", however, we don't have a Wallet to Claim it to."
                        return

                    #Claim the Reward.
                    var claim: Claim
                    try:
                        claim = newClaim(
                            cast[Mint](transactions[ourMint[]]),
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
                #body = await network.sync(header)
                raise newException(DataMissing, "")
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
