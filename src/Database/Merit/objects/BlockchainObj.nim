#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#BN lib.
import BN

#Hash lib.
import ../../../lib/Hash

#Verifications lib.
import ../../Verifications/Verifications

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#Difficulty, BlockHeader, and Block objects.
import DifficultyObj
import BlockHeaderObj
import BlockObj

#Serialize libs.
import ../../../Network/Serialize/SerializeCommon

import ../../../Network/Serialize/Merit/SerializeBlock
import ../../../Network/Serialize/Merit/ParseBlockHeader
import ../../../Network/Serialize/Merit/ParseBlock

import ../../../Network/Serialize/Merit/SerializeDifficulty
import ../../../Network/Serialize/Merit/ParseDifficulty

#Finals lib.
import finals

#Blockchain object.
finalsd:
    type Blockchain* = ref object of RootObj
        #DB Function Box.
        db*: DatabaseFunctionBox

        #Block time (part of the chain params).
        blockTime* {.final.}: uint
        #Starting Difficulty (part of the chain params).
        startDifficulty* {.final.}: Difficulty

        #Height.
        height*: uint
        #seq of every Blok Header.
        headers: seq[BlockHeader]
        #seq of all the Blocks in RAM.
        blocks: seq[Block]

        #Current Difficulty.
        difficulty*: Difficulty

#Create a Blockchain object.
proc newBlockchainObj*(
    db: DatabaseFunctionBox,
    genesis: string,
    blockTime: uint,
    startDifficultyArg: BN
): Blockchain {.raises: [
    ValueError,
    ArgonError,
    BLSError,
    LMDBError,
    FinalAttributeError
].} =
    #Create the start difficulty.
    var startDifficulty: Difficulty = newDifficultyObj(
        0,
        1,
        startDifficultyArg
    )

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
    var tip: string = ""
    try:
        tip = db.get("merit_tip")
    except:
        #If the tip isn't defined, this is the first boot.
        #Create a Genesis Block.
        var genesisBlock: Block = newBlockObj(
            0,
            genesis.pad(64).toArgonHash(),
            nil,
            @[],
            @[],
            0,
            0
        )
        #Grab the tip.
        tip = genesisBlock.header.hash.toString()

        #Save the tip and the Block.
        db.put("merit_tip", tip)
        db.put("merit_" & tip, genesisBlock.serialize())

        #Also set the Difficulty to the starting difficulty.
        db.put("merit_difficulty", result.difficulty.serialize())

    #Load every header.
    var
        headers: seq[BlockHeader]
        last: BlockHeader = parseBlockHeader(db.get("merit_" & tip).substr(0, BLOCK_HEADER_LEN - 1))
        i: int = 0
    headers = newSeq[BlockHeader](last.nonce + 1)

    while last.nonce != 0:
        headers[i] = last
        last = parseBlockHeader(db.get("merit_" & last.last.toString()).substr(0, BLOCK_HEADER_LEN - 1))
        inc(i)
    headers[i] = last

    #Set the blockchain's height and create a seq for the headers.
    result.height = uint(headers.len)
    result.headers = newSeq[BlockHeader](result.height)
    #Load the headers.
    for header in headers:
        result.headers[int(header.nonce)] = header

    #Load the blocks we want to cache.
    result.blocks = newSeq[Block](min(10, headers.len))
    if headers.len < 10:
        var loading: Block
        for h in countdown(headers.len - 1, 0):
            loading = parseBlock(db.get("merit_" & headers[h].hash.toString()))
            result.blocks[int(loading.header.nonce)] = loading
    else:
        #We store the headers in reverse order.
        for h in 0 ..< 10:
            result.blocks[9 - h] = parseBlock(db.get("merit_" & headers[h].hash.toString()))

    #Load the Difficulty.
    result.difficulty = parseDifficulty(db.get("merit_difficulty"))

#Adds a block.
proc add*(blockchain: Blockchain, newBlock: Block) {.raises: [LMDBError].} =
    inc(blockchain.height)
    blockchain.headers.add(newBlock.header)
    blockchain.blocks.add(newBlock)

    #Delete the block we're no longer caching.
    if blockchain.blocks.len > 10:
        blockchain.blocks.delete(0)

    #Save the block to the database.
    blockchain.db.put("merit_" & newBlock.header.hash.toString(), newBlock.serialize())
    blockchain.db.put("merit_tip", newBlock.header.hash.toString())

#Block getter.
proc `[]`*(blockchain: Blockchain, index: uint): Block {.raises: [
    ValueError,
    ArgonError,
    BLSError,
    LMDBError,
    FinalAttributeError
].} =
    if index >= blockchain.height:
        raise newException(ValueError, "Blockchain doesn't have enough blocks for that index.")

    if blockchain.height < 10:
        return blockchain.blocks[int(index)]

    if index >= blockchain.height - 10:
        result = blockchain.blocks[int(index - (blockchain.height - 10))]
    else:
        result = parseBlock(blockchain.db.get("merit_" & blockchain.headers[int(index)].hash.toString()))

#Gets the last Block.
func tip*(blockchain: Blockchain): Block {.inline, raises: [].} =
    blockchain.blocks[^1]
