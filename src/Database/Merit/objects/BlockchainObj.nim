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

#Difficulty and Block objects.
import DifficultyObj
import BlockObj

#Lists standard lib.
import lists

#Tables standard lib.
import tables

#Blockchain object.
type Blockchain* = object
    #DB Function Box.
    db*: DB

    #Genesis hash (derives from the chain params).
    genesis*: Hash[256]
    #Block time (part of the chain params).
    blockTime*: int
    #Starting Difficulty (part of the chain params).
    startDifficulty*: Difficulty

    #Height.
    height*: int
    #Linked List of the last 10 Blocks.
    blocks: DoublyLinkedList[Block]
    #Current Difficulty.
    difficulty*: Difficulty

    #RandomX Cache Key.
    cacheKey*: string

    #Miners from past blocks. Serves as a reverse lookup.
    miners*: Table[BLSPublicKey, uint16]

#Create a Blockchain object.
proc newBlockchainObj*(
    db: DB,
    genesisArg: string,
    blockTime: int,
    startDifficultyArg: Hash[256]
): Blockchain {.forceCheck: [].} =
    #Create the start difficulty.
    var startDifficulty: Difficulty
    try:
        startDifficulty = newDifficultyObj(
            0,
            2,
            startDifficultyArg
        )
    except ValueError:
        doAssert(false, "Couldn't create the Blockchain's starting difficulty.")

    #Create the Blockchain.
    var genesis: string = genesisArg.pad(32)
    try:
        result = Blockchain(
            db: db,

            genesis: genesis.toRandomXHash(),
            blockTime: blockTime,
            startDifficulty: startDifficulty,

            height: 0,
            blocks: initDoublyLinkedList[Block](),
            difficulty: startDifficulty,

            miners: initTable[BLSPublicKey, uint16]()
        )
    except ValueError as e:
        doAssert(false, "Couldn't convert the genesis to a hash, despite being padded to 32 bytes: " & e.msg)

    #Get the RandomX key from the DB.
    try:
        result.cacheKey = result.db.loadKey()
        setRandomXKey(result.cacheKey)
    except DBReadError:
        result.cacheKey = genesis
        setRandomXKey(result.cacheKey)
        result.db.saveUpcomingKey(result.cacheKey)
        result.db.saveKey(result.cacheKey)

    #Grab the height and tip from the DB.
    var tip: Hash[256]
    try:
        result.height = result.db.loadHeight()
        tip = result.db.loadTip()
    #If the height and tip weren't defined, this is the first boot.
    except DBReadError as e:
        #Make sure we didn't get the height but not the tip.
        if result.height != 0:
            doAssert(false, "Loaded the height but not the tip: " & e.msg)
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
            hash(genesisBlock.header)
        except ValueError as e:
            doAssert(false, "Couldn't create the Genesis Block due to a ValueError: " & e.msg)
        except BLSError as e:
            doAssert(false, "Couldn't create the Genesis Block due to a BLSError: " & e.msg)
        #Grab the tip.
        tip = genesisBlock.header.hash

        #Save the height, tip, the Genesis Block, and the starting Difficulty.
        result.db.saveHeight(result.height)
        result.db.saveTip(tip)
        result.db.save(0, genesisBlock)
        result.db.save(result.difficulty)

    #Load the last 10 Blocks.
    var last: Block
    for i in 0 ..< 10:
        try:
            last = result.db.loadBlock(tip)
            result.blocks.prepend(last)
        except DBReadError as e:
            doAssert(false, "Couldn't load a Block from the Database: " & e.msg)

        if last.header.last == result.genesis:
            break
        tip = last.header.last

    #Load the Difficulty.
    try:
        result.difficulty = result.db.loadDifficulty()
    except DBReadError as e:
        doAssert(false, "Couldn't load the Difficulty from the Database: " & e.msg)

    #Load the existing miners.
    var miners: seq[BLSPublicKey] = result.db.loadHolders()
    for m in 0 ..< miners.len:
        result.miners[miners[m]] = uint16(m)

#Adds a Block.
proc add*(
    blockchain: var Blockchain,
    newBlock: Block
) {.forceCheck: [].} =
    #Add the Block to the cache.
    blockchain.blocks.append(newBlock)
    #Delete the Block we're no longer caching.
    if blockchain.height >= 10:
        blockchain.blocks.remove(blockchain.blocks.head)

    #Save the Block to the database.
    blockchain.db.saveTip(newBlock.header.hash)
    blockchain.db.save(blockchain.height, newBlock)

    #Update the height.
    inc(blockchain.height)
    blockchain.db.saveHeight(blockchain.height)

    #Update miners, if necessary
    if newBlock.header.newMiner:
        blockchain.miners[newBlock.header.minerKey] = uint16(blockchain.miners.len)

    #If the height mod 2048 == 0, save the upcoming key.
    if blockchain.height mod 2048 == 0:
        blockchain.db.saveUpcomingKey(newBlock.header.hash.toString())
    elif blockchain.height mod 2048 == 64:
        var key: string
        try:
            key = blockchain.db.loadUpcomingKey()
        except DBReadError:
            doAssert(false, "Couldn't load the latest RandomX key.")

        blockchain.cacheKey = key
        setRandomXKey(blockchain.cacheKey)
        blockchain.db.saveKey(blockchain.cacheKey)

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
        raise newException(IndexError, "Attempted to get a Block with a negative nonce.")

    if nonce >= blockchain.height:
        raise newException(IndexError, "Specified nonce is greater than the Blockchain height.")
    elif nonce >= blockchain.height - 10:
        var res: DoublyLinkedNode[Block] = blockchain.blocks.head
        for _ in 0 ..< nonce - max((blockchain.height - 10), 0):
            res = res.next
        result = res.value
    else:
        try:
            result = blockchain.db.loadBlock(nonce)
        except DBReadError:
            raise newException(IndexError, "Specified nonce doesn't match any Block.")

proc `[]`*(
    blockchain: Blockchain,
    hash: Hash[256]
): Block {.forceCheck: [
    IndexError
].} =
    try:
        result = blockchain.db.loadBlock(hash)
    except DBReadError:
        raise newException(IndexError, "Block not found.")

#Gets the last Block.
func tail*(
    blockchain: Blockchain
): Block {.inline, forceCheck: [].} =
    blockchain.blocks.tail.value
