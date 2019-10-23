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

        functions.merit.getHeight = proc (): int {.inline, forceCheck: [].} =
            merit.blockchain.height
        functions.merit.getTail = proc (): Hash[384] {.inline, forceCheck: [].} =
            merit.blockchain.tail.header.hash

        functions.merit.getDifficulty = proc (): Difficulty {.inline, forceCheck: [].} =
            merit.blockchain.difficulty

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

        functions.merit.getPublicKey = proc (
            nick: uint16
        ): BLSPublicKey {.forceCheck: [
            IndexError
        ].} =
            if merit.state.holders.len <= int(nick):
                raise newException(IndexError, "Nickname doesn't exist.")
            result = merit.state.holders[nick]

        functions.merit.getNickname = proc (
            key: BLSPublicKey
        ): uint16 {.forceCheck: [
            IndexError
        ].} =
            try:
                result = merit.blockchain.miners[key]
            except KeyError as e:
                raise newException(IndexError, e.msg)

        functions.merit.getTotalMerit = proc (): int {.inline, forceCheck: [].} =
            merit.state.live
        functions.merit.getLiveMerit = proc (): int {.inline, forceCheck: [].} =
            merit.state.live
        functions.merit.getMerit = proc (
            nick: uint16
        ): int {.inline, forceCheck: [].} =
            merit.state[nick]

        functions.merit.isLive = proc (
            nick: uint16
        ): bool {.inline, forceCheck: [].} =
            true

        #Handle full blocks.
        functions.merit.addBlock = proc (
            newBlock: SketchyBlock,
            syncing: bool = false
        ) {.forceCheck: [
            ValueError,
            DataExists,
            NotConnected
        ], async.} =
            #Print that we're adding the Block.
            echo "Adding Block ", newBlock.data.header.hash, "."

            #Sync this Block.
            var sketcher: Sketcher
            try:
                await network.sync(
                    newBlock,
                    sketcher
                )
            except ValueError as e:
                fcRaise e
            except Exception as e:
                doAssert(false, "Couldn't sync this Block: " & e.msg)

            #Verify the Elements. Also see who has their Merit removed.
            var removed: seq[uint16] = @[]
            for elem in newBlock.data.body.elements:
                discard

            #Add the Block to the Blockchain.
            try:
                merit.processBlock(newBlock.data)
            except ValueError as e:
                fcRaise e
            except DataExists as e:
                fcRaise e
            except NotConnected as e:
                fcRaise e

            #Have the Consensus handle every person who suffered a MeritRemoval.
            for removee in removed:
                consensus.remove(removee)

            #Add the Block to the Epochs and State.
            var epoch: Epoch = merit.postProcessBlock(consensus)

            #Archive the Epochs.
            consensus.archive(merit.state, merit.epochs.latest, epoch)

            #Archive the hashes handled by the popped Epoch.
            transactions.archive(epoch)

            #Calculate the rewards.
            var rewards: seq[Reward] = epoch.calculate(merit.state)

            #Create the Mints (which ends up minting a total of 50000 Meri).
            var ourMint: Hash[384]
            for reward in rewards:
                var
                    mintHash: Hash[384] = transactions.mint(
                        merit.state.holders[int(reward.nick)],
                        reward.score * uint64(50)
                    )

                #If we have a miner wallet, check if the mint was to us.
                if (config.miner.initiated) and (config.miner.nick == reward.nick):
                    ourMint = mintHash

            #Commit the DBs.
            database.commit(merit.blockchain.height)

            echo "Successfully added the Block."

            if not syncing:
                #Broadcast the Block.
                functions.network.broadcast(
                    MessageType.BlockHeader,
                    newBlock.data.header.serialize()
                )

                #If we got a Mint...
                if ourMint != Hash[384]():
                    #Confirm we have a wallet.
                    if wallet.isNil:
                        echo "We got a Mint with hash ", ourMint, ", however, we don't have a Wallet to Claim it to."
                        return

                    #Claim the Reward.
                    var claim: Claim
                    try:
                        claim = newClaim(
                            transactions[ourMint].hash,
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
            DataMissing,
            DataExists,
            NotConnected
        ], async.} =
            try:
                merit.blockchain.testBlockHeader(header)
            except ValueError as e:
                fcRaise e
            except DataExists as e:
                fcRaise e
            except NotConnected as e:
                fcRaise e

            var newBlock: SketchyBlock
            try:
                newBlock = newSketchyBlockObj(header, await network.sync(header))
            except DataMissing as e:
                raise newException(ValueError, e.msg)
            except Exception as e:
                doAssert(false, "Network.sync(BlockHeader) threw an Exception despite catching all Exceptions: " & e.msg)

            try:
                await functions.merit.addBlock(newBlock)
            except ValueError as e:
                fcRaise e
            except DataMissing as e:
                fcRaise e
            except DataExists as e:
                fcRaise e
            except NotConnected as e:
                fcRaise e
            except Exception as e:
                doAssert(false, "addBlockByHeader threw an Exception despite catching all Exceptions: " & e.msg)
