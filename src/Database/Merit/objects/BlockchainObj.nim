#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Merit DB lib.
import ../../Filesystem/DB/MeritDB

#Difficulty, Miners, BlockHeader, and Block objects.
import DifficultyObj
import MinersObj
import BlockHeaderObj
import BlockObj

#Finals lib.
import finals

#Blockchain object.
finalsd:
    type Blockchain* = object
        #DB Function Box.
        db*: DB

        #Block time (part of the chain params).
        blockTime* {.final.}: int
        #Starting Difficulty (part of the chain params).
        startDifficulty* {.final.}: Difficulty

        #Height.
        height*: int
        #seq of every Blok Header.
        headers*: seq[BlockHeader]
        #seq of all the Blocks in RAM.
        blocks: seq[Block]

        #Current Difficulty.
        difficulty*: Difficulty

#Create a Blockchain object.
proc newBlockchainObj*(
    db: DB,
    genesis: string,
    blockTime: int,
    startDifficultyArg: Hash[384]
): Blockchain {.forceCheck: [].} =
    #Create the start difficulty.
    var startDifficulty: Difficulty
    try:
        startDifficulty = newDifficultyObj(
            0,
            1,
            startDifficultyArg
        )
    except ValueError:
        doAssert(false, "Couldn't create the Blockchain's starting difficulty.")

    #Create the Blockchain.
    result = Blockchain(
        db: db,

        blockTime: blockTime,
        startDifficulty: startDifficulty,

        difficulty: startDifficulty
    )
    #Finalize the Block Time and Start Difficulty.
    result.ffinalizeBlockTime()
    result.ffinalizeStartDifficulty()

    #Grab the tip from the DB.
    var tip: Hash[384]
    try:
        tip = result.db.loadTip()
    #If the tip isn't defined, this is the first boot.
    except DBReadError:
        #Create a Genesis Block.
        var genesisBlock: Block
        try:
            genesisBlock = newBlockObj(
                0,
                genesis.pad(48).toArgonHash(),
                nil,
                @[],
                newMinersObj(@[]),
                0,
                0
            )
        except ValueError as e:
            doAssert(false, "Couldn't create the Genesis Block due to a ValueError: " & e.msg)
        #Grab the tip.
        tip = genesisBlock.hash

        #Save the tip, the Genesis Block, and the starting Difficulty.
        result.db.saveTip(tip)
        result.db.save(genesisBlock)
        result.db.save(result.difficulty)

    #Load every header.
    var
        headers: seq[BlockHeader]
        last: BlockHeader
        i: int = 0
    try:
        last = result.db.loadBlockHeader(tip)
    except DBReadError as e:
        doAssert(false, "Couldn't load a Block Header from the Database: " & e.msg)
    headers = newSeq[BlockHeader](last.nonce + 1)

    while last.nonce != 0:
        headers[i] = last
        try:
            last = result.db.loadBlockHeader(last.last)
        except DBReadError as e:
            doAssert(false, "Couldn't load a Block Header from the Database: " & e.msg)
        inc(i)
    headers[i] = last

    #Set the blockchain's height and create a seq for the headers.
    result.height = headers.len
    result.headers = newSeq[BlockHeader](result.height)
    #Load the headers.
    for header in headers:
        result.headers[header.nonce] = header

    #Load the blocks we want to cache.
    result.blocks = newSeq[Block](min(10, headers.len))
    try:
        if headers.len < 10:
            var loading: Block
            for h in countdown(headers.len - 1, 0):
                loading = result.db.loadBlock(headers[h].hash)
                result.blocks[loading.nonce] = loading
        else:
            #We store the headers in reverse order.
            for h in 0 ..< 10:
                result.blocks[9 - h] = result.db.loadBlock(headers[h].hash)
    except DBReadError as e:
        doAssert(false, "Couldn't load a Block we're supposed to cache from the Database: " & e.msg)

    #Load the Difficulty.
    try:
        result.difficulty = result.db.loadDifficulty()
    except DBReadError as e:
        doAssert(false, "Couldn't load the Difficulty from the Database: " & e.msg)

#Adds a block.
proc add*(
    blockchain: var Blockchain,
    newBlock: Block
) {.forceCheck: [].} =
    inc(blockchain.height)
    blockchain.headers.add(newBlock.header)
    blockchain.blocks.add(newBlock)

    #Delete the block we're no longer caching.
    if blockchain.blocks.len > 10:
        blockchain.blocks.delete(0)

    #Save the block to the database.
    blockchain.db.save(newBlock)
    blockchain.db.saveTip(newBlock.hash)

#Block getters.
proc `[]`*(
    blockchain: Blockchain,
    nonce: int
): Block {.forceCheck: [
    IndexError
].} =
    if nonce >= blockchain.height:
        raise newException(IndexError, "That nonce is greater than the Blockchain height.")

    if blockchain.height < 10:
        return blockchain.blocks[nonce]

    if nonce >= blockchain.height - 10:
        result = blockchain.blocks[nonce - (blockchain.height - 10)]
    else:
        try:
            result = blockchain.db.loadBlock(blockchain.headers[nonce].hash)
        except DBReadError as e:
            doAssert(false, "Couldn't load a Block we were asked for from the Database: " & e.msg)

proc `[]`*(
    blockchain: Blockchain,
    hash: Hash[384]
): Block {.forceCheck: [
    IndexError
].} =
    for cached in blockchain.blocks:
        if cached.hash == hash:
            return cached

    try:
        result = blockchain.db.loadBlock(hash)
    except DBReadError:
        raise newException(IndexError, "Block not found.")

#Gets the last Block.
func tip*(
    blockchain: Blockchain
): Block {.inline, forceCheck: [].} =
    blockchain.blocks[^1]
