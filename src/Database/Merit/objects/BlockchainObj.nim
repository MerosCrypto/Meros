#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Merit DB lib.
import ../../Filesystem/DB/MeritDB

#Block object.
import BlockObj

#StInt external lib.
import stint

#Tables standard lib.
import tables

#Blockchain object.
type Blockchain* = object
  #DB Function Box.
  db*: DB

  #Genesis hash (derives from the chain params).
  genesis*: Hash[256]
  #Block time (part of the chain params).
  blockTime*: StUint[128]

  #Height.
  height*: int
  #Cache of the last 10 Blocks.
  blocks: seq[Block]
  #Cache of difficulties for this chain.
  difficulties*: seq[uint64]
  #Chain work.
  chainWork*: StUInt[128]

  #Miners from past blocks. Serves as a reverse lookup.
  miners*: Table[BLSPublicKey, uint16]

  #RandomX instance.
  rx*: RandomX

#Calculate a proper difficulty
proc calculateDifficulties*(
  db: DB,
  genesis: Hash[256],
  lastHeaderArg: BlockHeader
): seq[uint64] {.forceCheck: [].} =
  var lastHeader: BlockHeader = lastHeaderArg
  while result.len != 72:
    try:
      result = db.loadDifficulty(lastHeader.hash) & result
    except DBReadError as e:
      panic("Couldn't load a difficulty for a Block on the chain: " & e.msg)

    if lastHeader.last == genesis:
      break
    try:
      lastHeader = db.loadBlockHeader(lastHeader.last)
    except DBReadError as e:
      panic("Couldn't load a BlockHeader for a Block on the chain: " & e.msg)

#Create a Blockchain object.
proc newBlockchainObj*(
  db: DB,
  genesisArg: string,
  blockTime: int,
  initialDifficulty: uint64
): Blockchain {.forceCheck: [].} =
  #Create the Blockchain.
  var genesis: string = genesisArg.pad(32)
  try:
    result = Blockchain(
      db: db,

      genesis: genesis.toRandomXHash(),
      blockTime: stuint(blockTime, 128),

      height: 0,
      blocks: @[],
      difficulties: @[],

      miners: initTable[BLSPublicKey, uint16](),

      rx: newRandomX()
    )
  except ValueError as e:
    panic("Couldn't convert the genesis to a hash, despite being padded to 32 bytes: " & e.msg)

  #Get the RandomX key from the DB.
  try:
    result.rx.setCacheKey(result.db.loadKey())
  except DBReadError:
    result.rx.setCacheKey(genesis)
    result.db.saveKey(result.rx.cacheKey)

  #Grab the height and tip from the DB.
  var tip: Hash[256]
  try:
    result.height = result.db.loadHeight()
    tip = result.db.loadTip()
  #If the height and tip weren't defined, this is the first boot.
  except DBReadError as e:
    #Make sure we didn't get the height but not the tip.
    if result.height != 0:
      panic("Loaded the height but not the tip: " & e.msg)
    #Make sure we didn't get the tip but not the difficulty.
    if tip != Hash[256]():
      panic("Loaded the height and tip but not the difficulty: " & e.msg)
    result.height = 1

    #Create a Genesis Block.
    var genesisBlock: Block
    try:
      genesisBlock = newBlockObj(
        0,
        result.genesis,
        Hash[256](),
        0,
        "".pad(4),
        Hash[256](),
        newBLSPublicKey(),
        Hash[256](),
        @[],
        @[],
        newBLSSignature(),
        0,
        0,
        newBLSSignature()
      )
      result.rx.hash(genesisBlock.header)
    except ValueError as e:
      panic("Couldn't create the Genesis Block due to a ValueError: " & e.msg)
    except BLSError as e:
      panic("Couldn't create the Genesis Block due to a BLSError: " & e.msg)
    #Grab the tip.
    tip = genesisBlock.header.hash

    #Save the height, tip, the Genesis Block, the starting Difficulty, and the initial chain work.
    result.db.saveHeight(result.height)
    result.db.saveTip(tip)
    result.db.save(0, genesisBlock)
    result.db.save(genesisBlock.header.hash, initialDifficulty)
    result.db.save(genesisBlock.header.hash, stuint(initialDifficulty, 128))

  #Load the last 10 Blocks.
  var last: Block
  for i in 0 ..< 10:
    try:
      last = result.db.loadBlock(tip)
      result.blocks = @[last] & result.blocks
    except DBReadError as e:
      panic("Couldn't load a Block from the Database: " & e.msg)

    if last.header.last == result.genesis:
      break
    tip = last.header.last

  #Load the last 72 difficulties.
  result.difficulties = db.calculateDifficulties(result.genesis, result.blocks[^1].header)

  #Load the chain work.
  result.chainWork = result.db.loadChainWork(result.blocks[^1].header.hash)

  #Load the existing miners.
  var miners: seq[BLSPublicKey] = result.db.loadHolders()
  for m in 0 ..< miners.len:
    result.miners[miners[m]] = uint16(m)

#Add a Block.
proc add*(
  blockchain: var Blockchain,
  newBlock: Block
) {.forceCheck: [].} =
  #Add the Block to the cache.
  blockchain.blocks.add(newBlock)
  #Delete the Block we're no longer caching.
  if blockchain.height >= 10:
    blockchain.blocks.delete(0)

  #Save the Block to the database.
  blockchain.db.saveTip(newBlock.header.hash)
  blockchain.db.save(blockchain.height, newBlock)

  #Update the height.
  inc(blockchain.height)
  blockchain.db.saveHeight(blockchain.height)

  #Update miners, if necessary.
  if newBlock.header.newMiner:
    blockchain.miners[newBlock.header.minerKey] = uint16(blockchain.miners.len)

  #If the height mod 384 == 0, save the upcoming key.
  if blockchain.height mod 384 == 0:
    blockchain.db.saveUpcomingKey(newBlock.header.hash.toString())
  #If the height mod 384 == 12, switch to the upcoming key.
  elif (blockchain.height mod 384 == 12) and (blockchain.height != 12):
    var key: string
    try:
      key = blockchain.db.loadUpcomingKey()
    except DBReadError:
      panic("Couldn't load the latest RandomX key.")

    blockchain.rx.setCacheKey(key)
    blockchain.db.saveKey(blockchain.rx.cacheKey)

#Rewind the cache a Block.
proc rewindCache*(
  blockchain: var Blockchain
) {.forceCheck: [].} =
  blockchain.blocks.delete(blockchain.blocks.len - 1)
  if blockchain.height > 10:
    try:
      blockchain.blocks = @[blockchain.db.loadBlock(blockchain.blocks[0].header.last)] & blockchain.blocks
    except DBReadError as e:
      panic("Couldn't get the Block 11 Blocks before the tail when rewinding the cache: " & e.msg)

#Check if a Block exists.
proc hasBlock*(
  blockchain: Blockchain,
  hash: Hash[256]
): bool {.inline, forceCheck: [].} =
  blockchain.db.hasBlock(hash)

#Block getters.
proc `[]`*(
  blockchain: Blockchain,
  nonce: int
): Block {.forceCheck: [
  IndexError
].} =
  if nonce < 0:
    raise newLoggedException(IndexError, "Attempted to get a Block with a negative nonce.")

  if nonce >= blockchain.height:
    raise newLoggedException(IndexError, "Specified nonce is greater than the Blockchain height.")
  elif nonce >= blockchain.height - 10:
    result = blockchain.blocks[min(10, blockchain.blocks.len) - (blockchain.height - nonce)]
  else:
    try:
      result = blockchain.db.loadBlock(nonce)
    except DBReadError:
      raise newLoggedException(IndexError, "Specified nonce doesn't match any Block.")

proc `[]`*(
  blockchain: Blockchain,
  hash: Hash[256]
): Block {.forceCheck: [
  IndexError
].} =
  try:
    result = blockchain.db.loadBlock(hash)
  except DBReadError:
    raise newLoggedException(IndexError, "Block not found.")

#Get the last Block.
func tail*(
  blockchain: Blockchain
): Block {.inline, forceCheck: [].} =
  blockchain.blocks[^1]

#Get the height of a Block by its hash.
proc getHeightOf*(
  blockchain: Blockchain,
  hash: Hash[256]
): int {.inline, forceCheck: [].} =
  blockchain.db.loadHeight(hash)

#Get the chain work at a specific Block.
proc getChainWork*(
  blockchain: Blockchain,
  hash: Hash[256]
): StUInt[128] {.inline, forceCheck: [].} =
  blockchain.db.loadChainWork(hash)
