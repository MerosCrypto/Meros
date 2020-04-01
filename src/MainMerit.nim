include MainReorganization

proc mainMerit(
    params: ChainParams,
    database: DB,
    wallet: WalletDB,
    functions: GlobalFunctionBox,
    merit: ref Merit,
    consensus: ref Consensus,
    transactions: ref Transactions,
    network: Network,
    blockLock: ref Lock,
    innerBlockLock: ref Lock,
    lockedBlock: ref Hash[256]
) {.forceCheck: [].} =
    #Create the Merit.
    merit[] = newMerit(
        database,
        params.GENESIS,
        params.BLOCK_TIME,
        params.BLOCK_DIFFICULTY,
        params.DEAD_MERIT
    )

    functions.merit.getHeight = proc (): int {.forceCheck: [].} =
        merit.blockchain.height
    functions.merit.getTail = proc (): Hash[256] {.forceCheck: [].} =
        merit.blockchain.tail.header.hash

    functions.merit.getRandomX = proc (): RandomX {.forceCheck: [].} =
        merit.blockchain.rx
    functions.merit.getRandomXCacheKey = proc (): string {.forceCheck: [].} =
        merit.blockchain.rx.cacheKey

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
            raise newLoggedException(IndexError, "Requested the hash of the Block before the genesis.")

    functions.merit.getBlockHashAfter = proc (
        hash: Hash[256]
    ): Hash[256] {.forceCheck: [
        IndexError
    ].} =
        discard

    functions.merit.getDifficulty = proc (): uint64 {.forceCheck: [].} =
        merit.blockchain.difficulties[^1]

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
            raise newLoggedException(IndexError, "Nickname doesn't exist.")
        result = merit.state.holders[nick]

    functions.merit.getNickname = proc (
        key: BLSPublicKey
    ): uint16 {.forceCheck: [
        IndexError
    ].} =
        try:
            result = merit.blockchain.miners[key]
        except KeyError as e:
            raise newLoggedException(IndexError, e.msg)

    functions.merit.getTotalMerit = proc (): int {.forceCheck: [].} =
        merit.state.unlocked
    functions.merit.getUnlockedMerit = proc (): int {.forceCheck: [].} =
        merit.state.unlocked
    functions.merit.getMerit = proc (
        nick: uint16,
        height: int
    ): int {.forceCheck: [].} =
        merit.state[nick, height]

    functions.merit.isUnlocked = proc (
        nick: uint16
    ): bool {.forceCheck: [].} =
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
                if lockedBlock[] != sketchyBlock.data.header.hash:
                    release(lock[])
                    try:
                        await sleepAsync(milliseconds(50))
                    except Exception as e:
                        panic("Failed to complete an async sleep: " & e.msg)
                    continue
                break

            try:
                await sleepAsync(milliseconds(10))
            except Exception as e:
                panic("Failed to complete an async sleep: " & e.msg)

        #Print that we're adding the Block.
        logInfo "New Block", hash = sketchyBlock.data.header.hash

        #Construct a sketcher.
        var sketcher: Sketcher = sketcherArg
        if sketcher.len == 0:
            sketcher = newSketcher(
                (
                    proc (
                        nick: uint16
                    ): int {.raises: [].} =
                        functions.merit.getMerit(nick, functions.merit.getHeight())
                ),
                functions.consensus.isMalicious,
                cast[seq[VerificationPacket]](consensus[].getPending().packets)
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
            panic("Syncing a Block threw an error despite catching all exceptions: " & e.msg)
        finally:
            if not verified:
                logInfo "Invalid Block", hash = sketchyBlock.data.header.hash, reason = getCurrentException().msg

                lockedBlock[] = Hash[256]()
                release(lock[])

        logDebug "Synced Block", hash = newBlock.header.hash

        #Add every Verification Packet.
        for packet in newBlock.body.packets:
            functions.consensus.addVerificationPacket(packet)

        #Check who has their Merit removed.
        var removed: Table[uint16, MeritRemoval] = initTable[uint16, MeritRemoval]()
        for elem in newBlock.body.elements:
            if elem of MeritRemoval:
                consensus[].flag(merit.blockchain, merit.state, cast[MeritRemoval](elem))
                removed[elem.holder] = cast[MeritRemoval](elem)

        #Add the Block to the Blockchain.
        merit[].processBlock(newBlock)

        #Copy the State.
        var rewardsState: State = merit.state

        #Add the Block to the Epochs and State.
        var
            epoch: Epoch
            incd: uint16
            decd: int
        (epoch, incd, decd) = merit[].postProcessBlock()

        logDebug "Archiving Block", hash = newBlock.header.hash

        #Archive the Epochs.
        consensus[].archive(merit.state, newBlock.body.packets, newBlock.body.elements, epoch, incd, decd)

        #Have the Consensus handle every person who suffered a MeritRemoval.
        try:
            for removee in removed.keys():
                consensus[].remove(removed[removee], rewardsState[removee, rewardsState.processedBlocks])
        except KeyError as e:
            panic("Couldn't get the Merit Removal of a holder who just had one archived: " & e.msg)

        #Add every Element.
        for elem in elements:
            case elem:
                of SendDifficulty as sendDiff:
                    functions.consensus.addSendDifficulty(sendDiff)
                of DataDifficulty as dataDiff:
                    functions.consensus.addDataDifficulty(dataDiff)

        #Archive the hashes handled by the popped Epoch.
        transactions[].archive(newBlock, epoch)

        #If this header had a new miner, check if it was us.
        if newBlock.header.newMiner:
            if newBlock.header.minerKey == wallet.miner.publicKey:
                wallet.setMinerNick(uint16(merit.state.holders.len - 1))

        logDebug "Minting Meros", hash = newBlock.header.hash

        #Calculate the rewards.
        var rewards: seq[Reward] = epoch.calculate(rewardsState, removed)

        #If there are rewards, create the Mint.
        var receivedMint: int = -1
        if rewards.len != 0:
            transactions[].mint(newBlock.header.hash, rewards)

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
            panic("Passing a function that could raise an IndexError raised an IndexError: " & e.msg)

        logInfo "Added Block", hash = sketchyBlock.data.header.hash

        lockedBlock[] = Hash[256]()
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
                    panic("Created a Claim with a Mint yet newClaim raised a ValueError: " & e.msg)
                except IndexError as e:
                    panic("Couldn't grab a Mint we just added: " & e.msg)

                #Sign the claim.
                wallet.miner.sign(claim)

                #Emit it.
                try:
                    functions.transactions.addClaim(claim)
                except ValueError as e:
                    panic("Failed to add a Claim due to a ValueError: " & e.msg)
                except DataExists:
                    logNotice "Already added Claim", hash = claim.hash

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
                if lockedBlock[] != Hash[256]():
                    release(blockLock[])
                    try:
                        await sleepAsync(milliseconds(50))
                    except Exception as e:
                        panic("Failed to complete an async sleep: " & e.msg)
                    continue
                break

            try:
                await sleepAsync(milliseconds(10))
            except Exception as e:
                panic("Failed to complete an async sleep: " & e.msg)

        lockedBlock[] = sketchyBlock.data.header.hash
        release(blockLock[])

        try:
            await functions.merit.addBlockInternal(sketchyBlock, sketcherArg, syncing, blockLock)
        except ValueError as e:
            raise e
        except DataMissing as e:
            raise e
        except Exception as e:
            panic("addBlock threw an Exception despite catching all Exceptions: " & e.msg)

    functions.merit.addBlockByHeaderInternal = proc (
        header: BlockHeader,
        syncing: bool,
        lock: ref Lock
    ) {.forceCheck: [
        ValueError,
        DataMissing,
        DataExists
    ], async.} =
        while true:
            if tryAcquire(lock[]):
                if lockedBlock[] != Hash[256]():
                    release(lock[])
                    try:
                        await sleepAsync(milliseconds(50))
                    except Exception as e:
                        panic("Failed to complete an async sleep: " & e.msg)
                    continue
                break

            try:
                await sleepAsync(milliseconds(10))
            except Exception as e:
                panic("Failed to complete an async sleep: " & e.msg)
        lockedBlock[] = header.hash

        var sketchyBlock: SketchyBlock
        try:
            #Return if we already have this Block.
            if merit.blockchain.hasBlock(header.hash):
                raise newLoggedException(DataExists, "Block was already added.")

            #Sync previous Blocks if this header isn't connected.
            if merit.blockchain.tail.header.hash != header.last:
                var
                    increment: int = 32
                    queue: seq[Hash[256]] = @[header.hash]
                    #Malformed size used for the first loop iteration.
                    size: int = queue.len - increment
                    lastCommonBlock: Hash[256] = header.last
                if not merit.blockchain.hasBlock(header.last):
                    while not merit.blockchain.hasBlock(queue[^1]):
                        #If we ran out of Blocks, raise.
                        #The only three cases we run out of Blocks are:
                        #A) We synced forwards. We didn't.
                        #B) Their genesis doesn't match our genesis.
                        #C) Our peer is an idiot.
                        if queue.len != size + increment:
                            raise newLoggedException(ValueError, "Blockchain has a different genesis.")

                        #Update the size.
                        size = queue.len

                        #Get the list of Blocks before this Block.
                        try:
                            queue &= await syncAwait network.syncManager.syncBlockList(false, increment, queue[^1])
                        except DataMissing as e:
                            #This should only be raised if:
                            #A) The requested Block is unknown.
                            #B) We requested ONLY the Blocks before the genesis.
                            #The second is impossible as we break once we find a Block we know.
                            raise e
                        except Exception as e:
                            panic("requestBlockList threw an Exception despite catching all Exceptions: " & e.msg)

                    #Remove every Block we have from the queue's tail.
                    lastCommonBlock = merit.blockchain.tail.header.hash
                    for i in countdown(queue.len - 1, 1):
                        if merit.blockchain.hasBlock(queue[i]):
                            lastCommonBlock = queue[i]
                            queue.del(i)
                        else:
                            break

                #If the last Block on both chains isn't our tail, this is a potentially longer chain.
                if lastCommonBlock != merit.blockchain.tail.header.hash:
                    var altHeaders: seq[BlockHeader]
                    try:
                        altHeaders = await reorganize(
                            database,
                            merit[],
                            consensus,
                            transactions,
                            network,
                            lastCommonBlock,
                            queue,
                            header
                        )
                    except ValueError as e:
                        raise e
                    except DataMissing as e:
                        raise e
                    except Exception as e:
                        panic("Reorganizing the chain raised an Exception despite catching all Exceptions: " & e.msg)

                    lockedBlock[] = Hash[256]()
                    for header in altHeaders:
                        try:
                            await functions.merit.addBlockByHeaderInternal(header, true, innerBlockLock)
                        except ValueError as e:
                            logInfo "Reorganization failed", error = e.msg
                            raise e
                        except DataMissing as e:
                            logInfo "Reorganization failed", error = e.msg
                            raise e
                        except DataExists as e:
                            panic("Adding a missing Block before this alternate tail raised DataExists: " & e.msg)
                        except Exception as e:
                            panic("addBlockByHashInternal threw an Exception despite catching all Exceptions: " & e.msg)
                    logInfo "Reorganized"
                else:
                    #Clear the locked Block.
                    lockedBlock[] = Hash[256]()

                    #Add every previous Block.
                    for h in countdown(queue.len - 1, 1):
                        try:
                            await functions.merit.addBlockByHashInternal(queue[h], true, innerBlockLock)
                        except ValueError as e:
                            raise e
                        except DataMissing as e:
                            raise e
                        except DataExists as e:
                            panic("Adding a missing Block before this tail raised DataExists: " & e.msg)
                        except Exception as e:
                            panic("addBlockByHashInternal threw an Exception despite catching all Exceptions: " & e.msg)

                #Set back the locked Block.
                lockedBlock[] = header.hash

            if header.last != merit.blockchain.tail.header.hash:
                raise newException(ValueError, "Trying to add a Block which isn't after our current tail, despite calling reorganize and adding previous blocks.")

            #This executes twice in the case of reorgs.
            #That said, the only significant performance loss is in the double miner signature verify.
            try:
                testBlockHeader(
                    merit.blockchain.miners,
                    merit.state.holders,
                    merit.blockchain.tail.header,
                    merit.blockchain.difficulties[^1],
                    header
                )
            except ValueError as e:
                raise e

            try:
                sketchyBlock = newSketchyBlockObj(header, await syncAwait network.syncManager.syncBlockBody(header.hash, header.contents))
            except DataMissing as e:
                raise newLoggedException(ValueError, e.msg)
            except Exception as e:
                panic("SyncManager.syncBlockBody() threw an Exception despite catching all Exceptions: " & e.msg)
        except ValueError as e:
            raise e
        except DataMissing as e:
            raise e
        except DataExists as e:
            raise e
        finally:
            lockedBlock[] = Hash[256]()
            release(lock[])
        lockedBlock[] = sketchyBlock.data.header.hash

        try:
            await functions.merit.addBlockInternal(sketchyBlock, @[], syncing, lock)
        except ValueError as e:
            raise e
        except DataMissing as e:
            raise e
        except Exception as e:
            panic("addBlock threw an Exception despite catching all Exceptions: " & e.msg)

    functions.merit.addBlockByHeader = proc (
        header: BlockHeader,
        syncing: bool
    ) {.forceCheck: [
        ValueError,
        DataMissing,
        DataExists
    ], async.} =
        try:
            await functions.merit.addBlockByHeaderInternal(header, syncing, blockLock)
        except ValueError as e:
            raise e
        except DataMissing as e:
            raise e
        except DataExists as e:
            raise e
        except Exception as e:
            panic("addBlockByHeaderInternal threw an Exception despite catching all Exceptions: " & e.msg)

    functions.merit.addBlockByHashInternal = proc (
        hash: Hash[256],
        syncing: bool,
        lock: ref Lock
    ) {.forceCheck: [
        ValueError,
        DataMissing,
        DataExists
    ], async.} =
        #Return if we already have this Block.
        if merit.blockchain.hasBlock(hash):
            raise newLoggedException(DataExists, "Block was already added.")

        try:
            #This following line fails.
            #await functions.merit.addBlockByHeaderInternal(await syncAwait network.syncManager.syncBlockHeader(hash), syncing, lock)
            #https://github.com/nim-lang/Nim/issues/13815 is the reason why.
            #That said, even when the issue is fixed, it'll be a while before 1.0.8.
            #This longer code will last until at least then.
            var header: BlockHeader = await syncAwait network.syncManager.syncBlockHeader(hash)
            await functions.merit.addBlockByHeaderInternal(header, syncing, lock)
        except ValueError as e:
            raise e
        except DataMissing as e:
            raise e
        except DataExists as e:
            raise e
        except Exception as e:
            panic("addBlockByHeaderInternal/requestBlockHeader threw an Exception despite catching all Exceptions: " & e.msg)

    functions.merit.addBlockByHash = proc (
        peer: Peer,
        hash: Hash[256]
    ) {.forceCheck: [], async.} =
        try:
            await functions.merit.addBlockByHashInternal(hash, true, blockLock)
        except ValueError as e:
            peer.close(e.msg)
            return
        except DataMissing:
            discard
        except DataExists:
            discard
        except Exception as e:
            panic("addBlockByHashInternal threw an Exception despite catching all Exceptions: " & e.msg)

    #Tests a BlockHeader. Used by the RPC's addBlock method.
    functions.merit.testBlockHeader = proc (
        header: BlockHeader
    ) {.forceCheck: [
        ValueError
    ].} =
        if header.last != merit.blockchain.tail.header.hash:
            raise newException(ValueError, "Trying to add a Block which isn't after our current tail.")

        try:
            testBlockHeader(
                merit.blockchain.miners,
                merit.state.holders,
                merit.blockchain.tail.header,
                merit.blockchain.difficulties[^1],
                header
            )
        except ValueError as e:
            raise e
