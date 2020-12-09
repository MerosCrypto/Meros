import sets, tables

import stint

import ../../lib/[Errors, Util, Hash]
import ../../Wallet/MinerWallet

import ../Consensus/Elements/objects/[VerificationPacketObj, MeritRemovalObj]

import ../../Network/Serialize/Consensus/SerializeElement

import ../Filesystem/DB/MeritDB

import Difficulty, BlockHeader, Block, State

import objects/BlockchainObj
export BlockchainObj

proc newBlockchain*(
  db: DB,
  genesis: string,
  blockTime: int,
  initialDifficulty: uint64
): Blockchain {.inline, forceCheck: [].} =
  newBlockchainObj(
    db,
    genesis,
    blockTime,
    initialDifficulty
  )

#Verify a Block Header.
#Takes in so many arguments so we don't have to create a fake chain with all this info when we test forks.
proc testBlockHeader*(
  miners: Table[BLSPublicKey, uint16],
  lookup: seq[BLSPublicKey],
  hasMR: set[uint16],
  previous: BlockHeader,
  difficulty: uint64,
  header: BlockHeader
) {.forceCheck: [
  ValueError
].} =
  if header.hash.overflows(difficulty):
    raise newLoggedException(ValueError, "Block doesn't beat the difficulty.")

  if header.version != 0:
    raise newLoggedException(ValueError, "BlockHeader has an invalid version.")

  #This hardcoded magic number breaks this check on chains other than mainnet.
  #We need to calculate this based off the fixed block reward of 50 and defined amount of dead blocks.
  if (header.significant == 0) or (header.significant > uint16(26280)):
    raise newLoggedException(ValueError, "Invalid significant.")

  var key: BLSPublicKey
  if header.newMiner:
    #Check a miner with a nickname isn't being marked as new.
    if miners.hasKey(header.minerKey):
      raise newLoggedException(ValueError, "Header marks a miner with a nickname as new.")

    #Make sure the key isn't infinite.
    if header.minerKey.isInf:
      raise newLoggedException(ValueError, "Header has an infinite miner key.")

    #Grab the key.
    key = header.minerKey
  else:
    #Make sure the nick is valid.
    if header.minerNick >= uint16(lookup.len):
      raise newLoggedException(ValueError, "Header has an invalid nickname.")

    #Make sure they never had their Merit removed.
    if hasMR.contains(header.minerNick):
      raise newLoggedException(ValueError, "Header has a miner who had their Merit Removed.")

    key = lookup[header.minerNick]

  if (header.time <= previous.time) or (header.time > (getTime() + 300)):
    raise newLoggedException(ValueError, "Block has an invalid time.")

  try:
    if not header.signature.verify(newBLSAggregationInfo(key, header.interimHash)):
      raise newLoggedException(ValueError, "Block has an invalid signature.")
  except BLSError as e:
    panic("Failed to verify a BlockHeader's signature: " & e.msg)

proc processBlock*(
  blockchain: var Blockchain,
  newBlock: Block
) {.forceCheck: [].} =
  logDebug "Blockchain processing Block", hash = newBlock.header.hash

  blockchain.add(newBlock)

  #Calculate the next difficulty.
  var
    windowLength: int = calculateWindowLength(blockchain.height)
    time: uint32
  if windowLength != 0:
    try:
      time = blockchain.tail.header.time - blockchain[blockchain.height - windowLength].header.time
    except IndexError as e:
      panic("Couldn't get Block " & $(blockchain.height - windowLength) & " when the height is " & $blockchain.height & ": " & e.msg)

  blockchain.difficulties.add(calculateNextDifficulty(
    blockchain.blockTime,
    windowLength,
    blockchain.difficulties,
    time
  ))

  blockchain.db.save(newBlock.header.hash, blockchain.difficulties[^1])
  if blockchain.difficulties.len > 72:
    blockchain.difficulties.delete(0)

  #Update the chain work.
  blockchain.chainWork += stuint(blockchain.difficulties[^1], 128)
  blockchain.db.save(newBlock.header.hash, blockchain.chainWork)

#Set the cache key to what it was at a certain height.
proc setCacheKeyAtHeight*(
  blockchain: Blockchain,
  height: int
) {.forceCheck: [].} =
  var
    currentKeyHeight: int = height - 12
    blockUsedAsKey: int = (currentKeyHeight - (currentKeyHeight mod 384)) - 1
    blockUsedAsUpcomingKey: int = (height - (height mod 384)) - 1
    currentKey: string
  if blockUsedAsKey == -1:
    currentKey = blockchain.genesis.serialize()
  else:
    try:
      currentKey = blockchain[blockUsedAsKey].header.hash.serialize()
    except IndexError as e:
      panic("Couldn't grab the Block used as the current RandomX key: " & e.msg)

  #Rebuild the RandomX cache if needed.
  if currentKey != blockchain.rx.cacheKey:
    blockchain.rx.setCacheKey(currentKey)
    blockchain.db.saveKey(blockchain.rx.cacheKey)

  if blockUsedAsUpcomingKey == -1:
    #We don't need to do this since we don't load the upcoming key at Block 12.
    #The only reason we do is to ensure database equality between now and a historic moment.
    blockchain.db.deleteUpcomingKey()
  else:
    try:
      blockchain.db.saveUpcomingKey(blockchain[blockUsedAsUpcomingKey].header.hash.serialize())
    except IndexError as e:
      panic("Couldn't grab the Block used as the upcoming RandomX key: " & e.msg)

#Revert the Blockchain to a certain height.
proc revert*(
  blockchain: var Blockchain,
  state: var State,
  height: int
) {.forceCheck: [].} =
  var oldAmountOfHolders: int = state.holders.len
  state.revert(blockchain, height)
  state.pruneStatusesAndParticipations(oldAmountOfHolders)

  #Miners we changed the Merit of.
  #We should initially set this to blockchain[b].body.removals, instead of what we have both.
  var changedMerit: HashSet[uint16] = initHashSet[uint16]()

  #Revert the Blocks.
  for b in countdown(blockchain.height - 1, height):
    try:
      #If this Block had a new miner, delete it.
      if blockchain[b].header.newMiner:
        blockchain.miners.del(blockchain[b].header.minerKey)
        blockchain.db.deleteHolder()
        changedMerit.excl(uint16(blockchain.miners.len))
      #Else, mark that this miner's Merit changed.
      else:
        changedMerit.incl(uint16(blockchain[b].header.minerNick))

      #If this Block had a Merit Removal, mark the affected holder in changedMerit.
      for holder in blockchain[b].body.removals:
        changedMerit.incl(holder)
    except IndexError as e:
      panic("Couldn't grab the Block we're reverting past: " & e.msg)

    #If this Block killed Merit, restore it.
    if b > state.deadBlocks:
      var deadBlock: Block
      try:
        deadBlock = blockchain[b - state.deadBlocks]
      except IndexError as e:
        panic("Couldn't grab the Block whose Merit died when the Block we're reverting past was added: " & e.msg)

      if deadBlock.header.newMiner:
        try:
          changedMerit.incl(blockchain.miners[deadBlock.header.minerKey])
        except KeyError as e:
          panic("Couldn't get the nickname of a miner who's Merit died: " & e.msg)
      else:
        changedMerit.incl(deadBlock.header.minerNick)

      for holder in deadBlock.body.removals:
        changedMerit.incl(holder)

    #Delete the Block.
    try:
      blockchain.db.deleteBlock(b, blockchain[b].body.elements, blockchain[b].body.removals)
    except IndexError:
      panic("Couldn't get a Block's Elements before we deleted it.")
    #Rewind the cache.
    blockchain.rewindCache()

    #Decrement the height.
    dec(blockchain.height)

  #Save the reverted to tip.
  blockchain.db.saveTip(blockchain.tail.header.hash)

  #Save the reverted to height.
  blockchain.db.saveHeight(blockchain.height)

  #Load the reverted to difficulties.
  blockchain.difficulties = blockchain.db.calculateDifficulties(blockchain.genesis, blockchain.tail.header)
  #Load the chain work.
  blockchain.chainWork = blockchain.db.loadChainWork(blockchain.tail.header.hash)

  #Update the RandomX keys.
  blockchain.setCacheKeyAtHeight(blockchain.height)

  #Update the Merit of everyone who had their Merit changed.
  for holder in changedMerit:
    blockchain.db.saveMerit(holder, state[holder, state.processedBlocks])
