include MainDatabase

proc revertTo(
  database: DB,
  wallet: WalletDB,
  merit: Merit,
  consensus: ref Consensus,
  transactions: ref Transactions,
  height: int
) {.forceCheck: [].} =
  if height == merit.blockchain.height:
    logInfo "No need to revert"
    return
  consensus[].revert(merit.blockchain, merit.state, transactions[], height)
  transactions[].revert(merit.blockchain, height)
  merit.revert(height)
  database.commit(merit.blockchain.height)
  transactions[] = newTransactions(database, merit.blockchain)
  consensus[].postRevert(merit.blockchain, merit.state, transactions[])
  database.commit(merit.blockchain.height)
  logInfo "Reverted"

  if uint16(merit.state.holders.len) <= wallet.miner.nick:
    wallet.delMinerNick()

proc reorgRecover(
  database: DB,
  wallet: WalletDB,
  merit: Merit,
  consensus: ref Consensus,
  transactions: ref Transactions,
  lastCommonBlock: Hash[256],
  info: ReorganizationInfo
) {.forceCheck: [].} =
  var currentWork: StUInt[128] = merit.blockchain.getChainWork(merit.blockchain.tail.header.hash)
  if (
    (currentWork > info.existingWork) or
    (
      (currentWork == info.existingWork) and
      (info.altForkedBlock < info.existingForkedBlock)
    )
  ):
    logInfo "Keeping errored reorganization; still has more work", work = (currentWork - info.sharedWork).toShortHex()
    return
  else:
    logInfo "Reverting back to the fork point", hash = lastCommonBlock
    revertTo(database, wallet, merit, consensus, transactions, merit.blockchain.getHeightOf(lastCommonBlock))

proc reorganize(
  database: DB,
  wallet: WalletDB,
  merit: Merit,
  consensus: ref Consensus,
  transactions: ref Transactions,
  network: Network,
  lastCommonBlock: Hash[256],
  queue: seq[Hash[256]],
  tail: SketchyBlockHeader
): Future[ReorganizationInfo] {.forceCheck: [
  ValueError,
  DataMissing,
  NotEnoughWork
], async.} =
  #Print the tail's last hash as we know that. We can't know its hash due to RandomX cache keys.
  logInfo "Considering a reorganization", current = merit.blockchain.tail.header.hash, lastOfAlternate = tail.data.last, lastCommon = lastCommonBlock

  #Existing work values.
  result.sharedWork = merit.blockchain.getChainWork(lastCommonBlock)
  result.existingWork = merit.blockchain.getChainWork(merit.blockchain.tail.header.hash)

  var
    #Height of the last common Block.
    lastCommonHeight: int = merit.blockchain.getHeightOf(lastCommonBlock)
    #The old work is defined as the work of every Block from the chain tip to, but not including, the last common Block.
    oldWork: StUInt[128] = result.existingWork - result.sharedWork
    #The new work must be calculated.
    newWork: StUInt[128]
    #The last header we've processed.
    lastHeader: BlockHeader
    #Alternate miners/holders. Their status at the fork point advanced as we test new BlockHeaders.
    alternate: tuple[
      miners: Table[BLSPublicKey, uint16],
      holders: seq[BLSPublicKey]
    ] = merit.revertMinersAndHolders(lastCommonHeight)
    #In order to calculate it, we need to calculate the relevant difficulties.
    #This requires an accurate set of the difficulties leading up to it.
    difficulties: seq[uint64]
    #Current alternate height.
    altHeight: int = lastCommonHeight + 1

  try:
    lastHeader = merit.blockchain[lastCommonBlock].header
  except IndexError as e:
    panic("Couldn't load the last common Block: " & e.msg)
  difficulties = database.calculateDifficulties(merit.blockchain.genesis, lastHeader)

  try:
    result.existingForkedBlock = merit.blockchain[lastCommonHeight].header.hash
  except IndexError as e:
    panic("Couldn't get the forked Block on our current chain: " & e.msg)

  #Update the RandomX cache key to what it was at the time.
  merit.blockchain.setCacheKeyAtHeight(lastCommonHeight)
  #Prepare the upcoming key, if it's relevant.
  var upcomingHeight: int = (merit.blockchain.height - (merit.blockchain.height mod 384)) - 1
  var upcomingKey: string
  if upcomingHeight == -1:
    upcomingKey = merit.blockchain.genesis.serialize()
  else:
    try:
      upcomingKey = merit.blockchain[upcomingHeight].header.hash.serialize()
    except IndexError as e:
      panic("Failed to get the upcoming RandomX cache key: " & e.msg)

  #The queue has every Block between the last common Block and the alternate tip (exclusive).
  #The new work is therefore defined as the queue's work + the tail's.
  for h in countdown(high(queue), -1):
    #Update the last header, if this isn't the first iteration (which means there's no headers).
    if h != high(queue):
      lastHeader = result.headers[^1].data

    #Sync the missing header in the queue, if it's not the tip.
    if h != -1:
      try:
        result.headers.add(await syncAwait network.syncManager.syncBlockHeaderWithoutHashing(queue[h]))
      except DataMissing as e:
        raise e
      except Exception as e:
        panic("Couldn't sync a BlockHeader despite catching all Exceptions: " & e.msg)
    else:
      result.headers.add(tail)
    merit.blockchain.rx.hash(result.headers[^1].data, result.headers[^1].packetsQuantity)

    #Verify the new header.
    #If this is the first header, the last header has already been initially set.
    #Else, the header is the header before the end of the seq.
    try:
      testBlockHeader(
        alternate.miners,
        alternate.holders,
        #[
        We can't verify Blocks don't contain data from malicious Merit Holders.
        We'd need to sync the bodies, which we do later.
        While we could see if a malicious miner got Merit from a new Block, we couldn't find out which miners got a Merit Removal.
        This means we'd be working off historical data, and it just really ends up not worth it.
        ]#
        {},
        lastHeader,
        difficulties[^1],
        result.headers[^1].data
      )
    except ValueError as e:
      raise e

    #Update the alternate miners/holders accordingly.
    if result.headers[^1].data.newMiner:
      alternate.miners[result.headers[^1].data.minerKey] = uint16(alternate.miners.len)
      alternate.holders.add(result.headers[^1].data.minerKey)

    #Calculate what would be the next difficulty.
    var
      windowLength: int = calculateWindowLength(altHeight)
      time: uint32 = result.headers[^1].data.time
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
        time -= result.headers[nonceToGrab - lastCommonHeight].data.time

    newDifficulty = calculateNextDifficulty(
      merit.blockchain.blockTime,
      windowLength,
      difficulties,
      time,
      result.headers[^1].data.newMiner
    )

    #Update the difficulty queue.
    difficulties.add(newDifficulty)
    if difficulties.len > 72:
      difficulties.delete(0)

    #Add newDifficulty to newWork.
    newWork += stuint(newDifficulty, 128)

    #Increment the alternate chain's height.
    inc(altHeight)

    #Update the key if needed.
    if (altHeight - 1) mod 384 == 0:
      upcomingKey = result.headers[^1].data.hash.serialize()
    elif (altHeight - 1) mod 384 == 12:
      merit.blockchain.rx.setCacheKey(upcomingKey)

  #Convert the work to hex strings for logging purposes.
  var
    oldWorkStr: string = oldWork.toShortHex()
    newWorkStr: string = newWork.toShortHex()

  #If the new chain has more work, reorganize to it.
  result.altForkedBlock = result.headers[0].data.hash
  if (
    (newWork > oldWork) or
    ((newWork == oldWork) and (result.altForkedBlock < result.existingForkedBlock))
  ):
    #The first step is to revert everything to a point it can be advanced again.
    logInfo "Reorganizing", depth = merit.blockchain.height - lastCommonHeight, oldWork = oldWorkStr, newWork = newWorkStr
    revertTo(database, wallet, merit, consensus, transactions, lastCommonHeight)

    #We now return the headers so MainMerit adds the alternate Blocks.
    #This is done implicitly via result.
    #That said, the tail can't be returned as that's added via the function that called this.
    result.headers.del(high(result.headers))
  else:
    logInfo "Not reorganizing", oldWork = oldWorkStr, newWork = newWorkStr
    raise newException(NotEnoughWork, "Chain didn't have enough work to be worth reorganizing to.")
