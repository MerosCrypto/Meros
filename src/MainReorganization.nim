include MainDatabase

proc reorganize(
    lastCommonBlock: Hash[256],
    queue: seq[Hash[256]],
    tail: BlockHeader
): Future[void] {.forceCheck: [
    ValueError,
    DataMissing
], async.} =
    logInfo "Considering a reorganization", current = merit.blockchain.tail.header.hash, alternate = tail.hash, lastCommon = lastCommonBlock

    var
        #The old work is defined as the work of every Block from the chain tip to, but not including, the last common Block.
        oldWork: StUInt[128] = merit.blockchain.getChainWork(merit.blockchain.tail.header.hash) - merit.blockchain.getChainWork(lastCommonBlock)
        #The new work must be calculated.
        newWork: StUInt[128]
        #The last header we've processed.
        lastHeader: BlockHeader
        #Alternate miners/holders. Needed to verify the alternate headers.
        alternateMiners: Table[BLSPublicKey, uint16] = merit.blockchain.miners
        alternateHolders: seq[BLSPublicKey] = merit.state.holders
        #In order to calculate it, we need to calculate the relevant difficulties.
        #This requires an accurate set of the difficulties leading up to it.
        difficulties: seq[uint64]
        #Height of the last common Block.
        lastCommonHeight: int = merit.blockchain.getHeightOf(lastCommonBlock)
        #Current alternate height.
        altHeight: int = lastCommonHeight + 1
        #BlockHeaders, since we already synced them all.
        headers: seq[BlockHeader] = @[]
    try:
        lastHeader = merit.blockchain[lastCommonBlock].header
    except IndexError as e:
        panic("Couldn't load the last common Block: " & e.msg)
    difficulties = database.calculateDifficulties(merit.blockchain.genesis, lastHeader)

    #The new work is defined as the work of every Block in the queue.
    #The queue has every Block, including the new one being added, up to, but not including, the last common Block.
    for h in countdown(high(queue), 0):
        #Update the last header, if this isn't the first iteration (which means there's no headers).
        if h != high(queue):
            lastHeader = headers[^1]

        #Sync the missing header in the queue, if it's not the tip.
        if h != 0:
            try:
                headers.add(await syncAwait network.syncManager.syncBlockHeader(queue[h]))
            except DataMissing as e:
                raise e
            except Exception as e:
                panic("Couldn't sync a BlockHeader despite catching all Exceptions: " & e.msg)
        else:
            headers.add(tail)

        #Verify the new header.
        #If this is the first header, the last header has already been initially set.
        #Else, the header is the header before the end of the seq.
        try:
            testBlockHeader(
                alternateMiners,
                alternateHolders,
                lastHeader,
                difficulties[^1],
                headers[^1]
            )
        except ValueError as e:
            raise e

        #Update the alternate miners/holders accordingly.

        #Calculate what would be the next difficulty.
        var
            windowLength: int = calculateWindowLength(altHeight)
            time: uint32 = headers[^1].time
            newDifficulty: uint64
        #Don't finish calculating the time if the windowLength is 0.
        #The calculation will error out with an invalid index.
        if windowLength != 0:
            #The time is traditionally defined as the above, minus `blockchain[blockchain.height - windowLength].header.time`.
            #As soon as the reorg depth exceeds the window length, this will fail.
            #If:
            #- The height of both chains is 11.
            #- The window length is 5.
            #- The last common block is at height 6.
            #Asking for the Block with a nonce of 6 will return the Block with a height of 7.
            #This Block is different between the two chains.
            var nonceToGrab: int = altHeight - windowLength
            if nonceToGrab < lastCommonHeight:
                try:
                    time -= merit.blockchain[nonceToGrab].header.time
                except IndexError as e:
                    panic("Couldn't grab a Block with nonce " & $nonceToGrab & " despite the last common Block having a height of: " & $lastCommonHeight & ": " & e.msg)
            else:
                time -= headers[nonceToGrab - lastCommonHeight].time

        newDifficulty = calculateNextDifficulty(
            merit.blockchain.blockTime,
            windowLength,
            difficulties,
            time
        )

        #Update the difficulty queue.
        difficulties.add(newDifficulty)
        if difficulties.len > 72:
            difficulties.delete(0)

        #Add newDifficulty to newWork.
        newWork += stuint(newDifficulty, 128)

        #Increment the alternate chain's height.
        inc(altHeight)

    #Convert the work to hex strings for logging purposes.
    var
        oldWorkArr: array[16, byte] = oldWork.toByteArrayBE()
        oldWorkStr: string
        newWorkArr: array[16, byte] = newWork.toByteArrayBE()
        newWorkStr: string
    for b in 0 ..< 16:
        if (oldWorkArr[b] == 0) and (newWorkArr[b] == 0):
            continue
        oldWorkStr &= oldWorkArr[b].toHex()
        newWorkStr &= newWorkArr[b].toHex()

    #If the new chain has more work, reorganize to it.
    if (
        (newWork > oldWork) or
        ((newWork == oldWork) and (tail.hash < merit.blockchain.tail.header.hash))
    ):
        #The first step is to revert everything to a point it can be advanced again.
        var revertHeight: int = merit.blockchain.getHeightOf(lastCommonBlock)
        logInfo "Reorganizing", depth = merit.blockchain.height - revertHeight, oldWork = oldWorkStr, newWork = newWorkStr

        consensus.revert(merit.blockchain, merit.state, transactions, revertHeight)
        transactions.revert(merit.blockchain, revertHeight)
        merit.revert(revertHeight)
        database.commit(merit.blockchain.height)
        transactions = newTransactions(database, merit.blockchain)
        consensus.postRevert(merit.blockchain, merit.state, transactions)

        #The second step is to actually add all the new Blocks.
        #!

        logInfo "Reorganized"
    else:
        logInfo "Not reorganizing", oldWork = oldWorkStr, newWork = newWorkStr
