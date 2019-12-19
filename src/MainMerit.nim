include MainDatabase

proc mainMerit() {.forceCheck: [].} =
    {.gcsafe.}:
        #Create the Merit.
        merit = newMerit(
            database,
            params.GENESIS,
            params.BLOCK_TIME,
            params.BLOCK_DIFFICULTY,
            params.DEAD_MERIT
        )

        functions.merit.getHeight = proc (): int {.inline, forceCheck: [].} =
            merit.blockchain.height
        functions.merit.getTail = proc (): Hash[384] {.inline, forceCheck: [].} =
            merit.blockchain.tail.header.hash

        functions.merit.getBlockHashBefore = proc (
            hash: Hash[384]
        ): Hash[384] {.forceCheck: [
            IndexError
        ].} =
            try:
                result = merit.blockchain[hash].header.last
            except IndexError as e:
                raise e

            if result == merit.blockchain.genesis:
                raise newException(IndexError, "Requested the hash of the Block before the genesis.")

        functions.merit.getBlockHashAfter = proc (
            hash: Hash[384]
        ): Hash[384] {.forceCheck: [
            IndexError
        ].} =
            discard

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
                raise e

        functions.merit.getBlockByHash = proc (
            hash: Hash[384]
        ): Block {.forceCheck: [
            IndexError
        ].} =
            try:
                result = merit.blockchain[hash]
            except IndexError as e:
                raise e

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
            merit.state.unlocked
        functions.merit.getUnlockedMerit = proc (): int {.inline, forceCheck: [].} =
            merit.state.unlocked
        functions.merit.getMerit = proc (
            nick: uint16
        ): int {.inline, forceCheck: [].} =
            merit.state[nick]

        functions.merit.isUnlocked = proc (
            nick: uint16
        ): bool {.inline, forceCheck: [].} =
            true

        #Handle full blocks.
        functions.merit.addBlock = proc (
            sketchyBlock: SketchyBlock,
            sketcherArg: Sketcher,
            syncing: bool
        ) {.forceCheck: [
            ValueError,
            DataMissing
        ], async.} =
            #Print that we're adding the Block.
            echo "Adding Block ", sketchyBlock.data.header.hash, "."

            #Construct a sketcher.
            var sketcher: Sketcher = sketcherArg
            if sketcher.len == 0:
                sketcher = newSketcher(
                functions.merit.getMerit,
                    functions.consensus.isMalicious,
                    consensus.getPending().packets
                )

            #Sync this Block.
            var newBlock: Block
            try:
                newBlock = await network.sync(
                    merit.state,
                    sketchyBlock,
                    sketcher
                )
            except ValueError as e:
                raise e
            except DataMissing as e:
                raise e
            except Exception as e:
                doAssert(false, "Syncing a Block threw an error despite catching all exceptions: " & e.msg)

            #Verify the Elements. Also check who has their Merit removed.
            var removed: seq[uint16] = @[]
            for elem in newBlock.body.elements:
                discard

            #Add the Block to the Blockchain.
            try:
                merit.processBlock(newBlock)
            except ValueError as e:
                raise e

            #Have the Consensus handle every person who suffered a MeritRemoval.
            for removee in removed:
                consensus.remove(removee)

            #Add the Block to the Epochs and State.
            var epoch: Epoch = merit.postProcessBlock()

            #Archive the Epochs.
            consensus.archive(merit.state, newBlock.body.packets, epoch)

            #Archive the hashes handled by the popped Epoch.
            transactions.archive(epoch)

            #Calculate the rewards.
            var rewards: seq[Reward] = epoch.calculate(merit.state)

            #If there are rewards, create the Mint.
            var receivedMint: int = -1
            if rewards.len != 0:
                transactions.mint(newBlock.header.hash, rewards)

                #If we have a miner wallet, check if a mint was to us.
                if config.miner.initiated:
                    for r in 0 ..< rewards.len:
                        if config.miner.nick == rewards[r].nick:
                            receivedMint = r

            #Commit the DBs.
            database.commit(merit.blockchain.height)

            echo "Successfully added the Block."

            if not syncing:
                #Broadcast the Block.
                functions.network.broadcast(
                    MessageType.BlockHeader,
                    newBlock.header.serialize()
                )

                #If we got a Mint...
                if receivedMint != -1:
                    #Confirm we have a wallet.
                    if wallet.isNil:
                        echo "We got a Mint with hash ", newBlock.header.hash, ", however, we don't have a Wallet to Claim it to."
                        return

                    #Claim the Reward.
                    var claim: Claim
                    try:
                        claim = newClaim(
                            newFundedInput(newBlock.header.hash, receivedMint),
                            wallet.publicKey
                        )
                    except ValueError as e:
                        doAssert(false, "Created a Claim with a Mint yet newClaim raised a ValueError: " & e.msg)
                    except IndexError as e:
                        doAssert(false, "Couldn't grab a Mint we just added: " & e.msg)

                    #Sign the claim.
                    config.miner.sign(claim)

                    #Emit it.
                    try:
                        functions.transactions.addClaim(claim)
                    except ValueError as e:
                        doAssert(false, "Failed to add a Claim due to a ValueError: " & e.msg)
                    except DataExists:
                        echo "Already added a Claim for the incoming Mint."

        functions.merit.addBlockByHeader = proc (
            header: BlockHeader,
            syncing: bool
        ) {.forceCheck: [
            ValueError,
            DataMissing,
            DataExists,
            NotConnected
        ], async.} =
            #Return if we already have this Block.
            if merit.blockchain.hasBlock(header.hash):
                raise newException(DataExists, "Block was already added.")

            #Sync previous Blocks if this header isn't connected.
            if merit.blockchain.tail.header.hash != header.last:
                var
                    increment: int = 32
                    queue: seq[Hash[384]] = @[header.hash]
                    #Malformed size used for the first loop iteration.
                    size: int = queue.len - increment
                while not merit.blockchain.hasBlock(queue[^1]):
                    #If we ran out of Blocks, raise.
                    #The only three cases we run out of Blocks are:
                    #A) We synced forwards. We didn't.
                    #B) Their genesis doesn't match our genesis.
                    #C) Our peer is an idiot.
                    if queue.len != size + increment:
                        raise newException(ValueError, "Blockchain has a different genesis.")

                    #Update the size.
                    size = queue.len

                    #Get the list of Blocks before this Block.
                    try:
                        queue &= await network.requestBlockList(false, increment, queue[^1])
                    except DataMissing as e:
                        #This should only be raised if:
                        #A) The requested Block is unknown.
                        #B) We requested ONLY the Blocks before the genesis.
                        #The second is impossible as we break once we find a Block we know.
                        raise e
                    except Exception as e:
                        doAssert(false, "requestBlockList threw an Exception despite catching all Exceptions: " & e.msg)

                #Remove every Block we have from the queue's tail.
                var lastRemoved: Hash[384] = merit.blockchain.tail.header.hash
                for i in countdown(queue.len - 1, 1):
                    if merit.blockchain.hasBlock(queue[i]):
                        lastRemoved = queue[i]
                        queue.del(i)

                #If the last Block on both chains isn't our tail, raise NotConnected.
                if lastRemoved != merit.blockchain.tail.header.hash:
                    raise newException(NotConnected, "Blockchain split.")

                #Add every previous Block.
                for h in countdown(queue.len - 1, 1):
                    try:
                        await functions.merit.addBlockByHash(queue[h], true)
                    except ValueError as e:
                        raise e
                    except DataMissing as e:
                        raise e
                    except DataExists as e:
                        raise e
                    except NotConnected as e:
                        doAssert(false, "Parent addBlockByHeader didn't detect a Blockchain split: " & e.msg)
                    except Exception as e:
                        doAssert(false, "addBlockByHash threw an Exception despite catching all Exceptions: " & e.msg)

            try:
                merit.blockchain.testBlockHeader(header)
            except ValueError as e:
                raise e
            except NotConnected as e:
                doAssert(false, "Tried to add a Block that wasn't after the last Block: " & e.msg)

            var sketchyBlock: SketchyBlock
            try:
                sketchyBlock = newSketchyBlockObj(header, await network.requestBlockBody(header.hash))
            except DataMissing as e:
                raise newException(ValueError, e.msg)
            except Exception as e:
                doAssert(false, "Network.requestBlockBody() threw an Exception despite catching all Exceptions: " & e.msg)

            try:
                await functions.merit.addBlock(sketchyBlock, @[], syncing)
            except ValueError as e:
                raise e
            except DataMissing as e:
                raise e
            except Exception as e:
                doAssert(false, "addBlock threw an Exception despite catching all Exceptions: " & e.msg)

        functions.merit.addBlockByHash = proc (
            hash: Hash[384],
            syncing: bool
        ) {.forceCheck: [
            ValueError,
            DataMissing,
            DataExists,
            NotConnected
        ], async.} =
            #Return if we already have this Block.
            if merit.blockchain.hasBlock(hash):
                return

            try:
                await functions.merit.addBlockByHeader(await network.requestBlockHeader(hash), syncing)
            except ValueError as e:
                raise e
            except DataMissing as e:
                raise e
            except DataExists as e:
                raise e
            except NotConnected as e:
                raise e
            except Exception as e:
                doAssert(false, "addBlockByHeader/requestBlockHeader threw an Exception despite catching all Exceptions: " & e.msg)

        #Tests a BlockHeader. Used by the RPC's addBlock method.
        functions.merit.testBlockHeader = proc (
            header: BlockHeader
        ) {.forceCheck: [
            ValueError,
            NotConnected
        ].} =
            try:
                merit.blockchain.testBlockHeader(header)
            except ValueError as e:
                raise e
            except NotConnected as e:
                raise e
