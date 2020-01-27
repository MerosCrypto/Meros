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
        functions.merit.getTail = proc (): Hash[256] {.inline, forceCheck: [].} =
            merit.blockchain.tail.header.hash

        functions.merit.getRandomXCacheKey = proc (): string {.inline, forceCheck: [].} =
            merit.blockchain.cacheKey

        functions.merit.getBlockHashBefore = proc (
            hash: Hash[256]
        ): Hash[256] {.forceCheck: [
            IndexError
        ].} =
            try:
                result = merit.blockchain[hash].header.last
            except IndexError as e:
                raise e

            if result == merit.blockchain.genesis:
                raise newException(IndexError, "Requested the hash of the Block before the genesis.")

        functions.merit.getBlockHashAfter = proc (
            hash: Hash[256]
        ): Hash[256] {.forceCheck: [
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
            hash: Hash[256]
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
        functions.merit.addBlockInternal = proc (
            sketchyBlock: SketchyBlock,
            sketcherArg: Sketcher,
            syncing: bool,
            lock: ref Lock
        ) {.forceCheck: [
            ValueError,
            DataMissing
        ], async.} =
            while true:
                if tryAcquire(lock[]):
                    if lockedBlock != sketchyBlock.data.header.hash:
                        release(lock[])
                        try:
                            await sleepAsync(50)
                        except Exception as e:
                            doAssert(false, "Failed to complete an async sleep: " & e.msg)
                        continue
                    break

                try:
                    await sleepAsync(10)
                except Exception as e:
                    doAssert(false, "Failed to complete an async sleep: " & e.msg)

            #Print that we're adding the Block.
            echo "Adding Block ", sketchyBlock.data.header.hash, "."

            #Construct a sketcher.
            var sketcher: Sketcher = sketcherArg
            if sketcher.len == 0:
                sketcher = newSketcher(
                    functions.merit.getMerit,
                    functions.consensus.isMalicious,
                    cast[seq[VerificationPacket]](consensus.getPending().packets)
                )

            #Sync this Block.
            var
                newBlock: Block
                elements: seq[BlockElement]
                verified: bool = false
            try:
                (newBlock, elements) = await network.syncManager.sync(
                    merit.state,
                    sketchyBlock,
                    sketcher
                )
                verified = true
            except ValueError as e:
                raise e
            except DataMissing as e:
                raise e
            except Exception as e:
                doAssert(false, "Syncing a Block threw an error despite catching all exceptions: " & e.msg)
            finally:
                if not verified:
                    lockedBlock = Hash[256]()
                    release(lock[])

            #Add every Verification Packet.
            for packet in newBlock.body.packets:
                functions.consensus.addVerificationPacket(packet)

            #Check who has their Merit removed.
            var removed: set[uint16] = {}
            for elem in newBlock.body.elements:
                if elem of MeritRemoval:
                    consensus.flag(merit.blockchain, merit.state, cast[MeritRemoval](elem))
                    removed.incl(elem.holder)

            #Add the Block to the Blockchain.
            merit.processBlock(newBlock)

            #Copy the State.
            var rewardsState: State = merit.state

            #Add the Block to the Epochs and State.
            var
                epoch: Epoch
                incd: uint16
                decd: int
            (epoch, incd, decd) = merit.postProcessBlock()

            #Archive the Epochs.
            consensus.archive(merit.state, newBlock.body.packets, newBlock.body.elements, epoch, incd, decd)

            #Have the Consensus handle every person who suffered a MeritRemoval.
            for removee in removed:
                consensus.remove(removee, rewardsState[removee])

            #Add every Element.
            for elem in elements:
                case elem:
                    of SendDifficulty as sendDiff:
                        functions.consensus.addSendDifficulty(sendDiff)
                    of DataDifficulty as dataDiff:
                        functions.consensus.addDataDifficulty(dataDiff)

            #Archive the hashes handled by the popped Epoch.
            transactions.archive(epoch)

            #If this header had a new miner, check if it was us.
            if newBlock.header.newMiner:
                if newBlock.header.minerKey == wallet.miner.publicKey:
                    wallet.setMinerNick(uint16(merit.state.holders.len - 1))

            #Calculate the rewards.
            var rewards: seq[Reward] = epoch.calculate(rewardsState, removed)

            #If there are rewards, create the Mint.
            var receivedMint: int = -1
            if rewards.len != 0:
                transactions.mint(newBlock.header.hash, rewards)

                #If we have a miner wallet, check if a mint was to us.
                if wallet.miner.initiated:
                    for r in 0 ..< rewards.len:
                        if wallet.miner.nick == rewards[r].nick:
                            receivedMint = r

            #Commit the DBs.
            database.commit(merit.blockchain.height)
            try:
                wallet.commit(epoch, functions.transactions.getTransaction)
            except IndexError as e:
                doAssert(false, "Passing a function that could raise an IndexError raised an IndexError: " & e.msg)

            echo "Successfully added the Block."

            lockedBlock = Hash[256]()
            release(lock[])

            if not syncing:
                #Broadcast the Block.
                functions.network.broadcast(
                    MessageType.BlockHeader,
                    newBlock.header.serialize()
                )

                #If we got a Mint...
                if receivedMint != -1:
                    #Claim the Reward.
                    var claim: Claim
                    try:
                        claim = newClaim(
                            newFundedInput(newBlock.header.hash, receivedMint),
                            wallet.wallet.external.next().publicKey
                        )
                    except ValueError as e:
                        doAssert(false, "Created a Claim with a Mint yet newClaim raised a ValueError: " & e.msg)
                    except IndexError as e:
                        doAssert(false, "Couldn't grab a Mint we just added: " & e.msg)

                    #Sign the claim.
                    wallet.miner.sign(claim)

                    #Emit it.
                    try:
                        functions.transactions.addClaim(claim)
                    except ValueError as e:
                        doAssert(false, "Failed to add a Claim due to a ValueError: " & e.msg)
                    except DataExists:
                        echo "Already added a Claim for the incoming Mint."

        functions.merit.addBlock = proc (
            sketchyBlock: SketchyBlock,
            sketcherArg: Sketcher,
            syncing: bool
        ) {.forceCheck: [
            ValueError,
            DataMissing
        ], async.} =
            while true:
                if tryAcquire(blockLock[]):
                    if lockedBlock != Hash[256]():
                        release(blockLock[])
                        try:
                            await sleepAsync(50)
                        except Exception as e:
                            doAssert(false, "Failed to complete an async sleep: " & e.msg)
                        continue
                    break

                try:
                    await sleepAsync(10)
                except Exception as e:
                    doAssert(false, "Failed to complete an async sleep: " & e.msg)

            lockedBlock = sketchyBlock.data.header.hash
            release(blockLock[])

            try:
                await functions.merit.addBlockInternal(sketchyBlock, sketcherArg, syncing, blockLock)
            except ValueError as e:
                raise e
            except DataMissing as e:
                raise e
            except Exception as e:
                doAssert(false, "addBlock threw an Exception despite catching all Exceptions: " & e.msg)

        functions.merit.addBlockByHeaderInternal = proc (
            header: BlockHeader,
            syncing: bool,
            lock: ref Lock
        ) {.forceCheck: [
            ValueError,
            DataMissing,
            DataExists,
            NotConnected
        ], async.} =
            while true:
                if tryAcquire(lock[]):
                    if lockedBlock != Hash[256]():
                        release(lock[])
                        try:
                            await sleepAsync(50)
                        except Exception as e:
                            doAssert(false, "Failed to complete an async sleep: " & e.msg)
                        continue
                    break

                try:
                    await sleepAsync(10)
                except Exception as e:
                    doAssert(false, "Failed to complete an async sleep: " & e.msg)
            lockedBlock = header.hash

            var sketchyBlock: SketchyBlock
            try:
                #Return if we already have this Block.
                if merit.blockchain.hasBlock(header.hash):
                    raise newException(DataExists, "Block was already added.")

                #Sync previous Blocks if this header isn't connected.
                if merit.blockchain.tail.header.hash != header.last:
                    var
                        increment: int = 32
                        queue: seq[Hash[256]] = @[header.hash]
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
                            queue &= await network.syncManager.syncBlockList(false, increment, queue[^1])
                        except DataMissing as e:
                            #This should only be raised if:
                            #A) The requested Block is unknown.
                            #B) We requested ONLY the Blocks before the genesis.
                            #The second is impossible as we break once we find a Block we know.
                            raise e
                        except Exception as e:
                            doAssert(false, "requestBlockList threw an Exception despite catching all Exceptions: " & e.msg)

                    #Remove every Block we have from the queue's tail.
                    var lastRemoved: Hash[256] = merit.blockchain.tail.header.hash
                    for i in countdown(queue.len - 1, 1):
                        if merit.blockchain.hasBlock(queue[i]):
                            lastRemoved = queue[i]
                            queue.del(i)

                    #If the last Block on both chains isn't our tail, raise NotConnected.
                    if lastRemoved != merit.blockchain.tail.header.hash:
                        raise newException(NotConnected, "Blockchain split.")

                    #Clear the locked Block.
                    lockedBlock = Hash[256]()

                    #Add every previous Block.
                    for h in countdown(queue.len - 1, 1):
                        try:
                            await functions.merit.addBlockByHashInternal(queue[h], true, innerBlockLock)
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

                    #Set back the locked Block.
                    lockedBlock = header.hash

                try:
                    merit.blockchain.testBlockHeader(merit.state.holders, header)
                except ValueError as e:
                    raise e
                except NotConnected as e:
                    doAssert(false, "Tried to add a Block that wasn't after the last Block: " & e.msg)

                try:
                    sketchyBlock = newSketchyBlockObj(header, await network.syncManager.syncBlockBody(header.hash, header.contents))
                except DataMissing as e:
                    raise newException(ValueError, e.msg)
                except Exception as e:
                    doAssert(false, "SyncManager.syncBlockBody() threw an Exception despite catching all Exceptions: " & e.msg)
            except ValueError as e:
                raise e
            except DataMissing as e:
                raise e
            except DataExists as e:
                raise e
            except NotConnected as e:
                raise e
            finally:
                lockedBlock = Hash[256]()
                release(lock[])
            lockedBlock = sketchyBlock.data.header.hash

            try:
                await functions.merit.addBlockInternal(sketchyBlock, @[], syncing, lock)
            except ValueError as e:
                raise e
            except DataMissing as e:
                raise e
            except Exception as e:
                doAssert(false, "addBlock threw an Exception despite catching all Exceptions: " & e.msg)

        functions.merit.addBlockByHeader = proc (
            header: BlockHeader,
            syncing: bool
        ) {.forceCheck: [
            ValueError,
            DataMissing,
            DataExists,
            NotConnected
        ], async.} =
            try:
                await functions.merit.addBlockByHeaderInternal(header, syncing, blockLock)
            except ValueError as e:
                raise e
            except DataMissing as e:
                raise e
            except DataExists as e:
                raise e
            except NotConnected as e:
                raise e
            except Exception as e:
                doAssert(false, "addBlockByHeaderInternal threw an Exception despite catching all Exceptions: " & e.msg)

        functions.merit.addBlockByHashInternal = proc (
            hash: Hash[256],
            syncing: bool,
            lock: ref Lock
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
                await functions.merit.addBlockByHeaderInternal(await network.syncManager.syncBlockHeader(hash), syncing, lock)
            except ValueError as e:
                raise e
            except DataMissing as e:
                raise e
            except DataExists as e:
                raise e
            except NotConnected as e:
                raise e
            except Exception as e:
                doAssert(false, "addBlockByHeaderInternal/requestBlockHeader threw an Exception despite catching all Exceptions: " & e.msg)

        functions.merit.addBlockByHash = proc (
            hash: Hash[256],
            syncing: bool
        ) {.forceCheck: [
            ValueError,
            DataMissing,
            DataExists,
            NotConnected
        ], async.} =
            try:
                await functions.merit.addBlockByHashInternal(hash, syncing, blockLock)
            except ValueError as e:
                raise e
            except DataMissing as e:
                raise e
            except DataExists as e:
                raise e
            except NotConnected as e:
                raise e
            except Exception as e:
                doAssert(false, "addBlockByHashInternal threw an Exception despite catching all Exceptions: " & e.msg)

        #Tests a BlockHeader. Used by the RPC's addBlock method.
        functions.merit.testBlockHeader = proc (
            header: BlockHeader
        ) {.forceCheck: [
            ValueError,
            NotConnected
        ].} =
            try:
                merit.blockchain.testBlockHeader(merit.state.holders, header)
            except ValueError as e:
                raise e
            except NotConnected as e:
                raise e
