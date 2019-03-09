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
import ../../../Network/Serialize/Merit/SerializeBlock
import ../../../Network/Serialize/Merit/ParseBlock

#Finals lib.
import finals

#String utils standard lib.
import strutils

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
    genesis: string,
    blockTime: uint,
    startDifficultyArg: BN,
    db: DatabaseFunctionBox
): Blockchain {.raises: [].} =
    var startDifficulty: Difficulty = newDifficultyObj(
        0,
        1,
        startDifficultyArg
    )

    result = Blockchain(
        db: db,

        blockTime: blockTime,
        startDifficulty: startDifficulty,

        blocks: @[],

        difficulty: startDifficulty
    )
    result.ffinalizeBlockTime()
    result.ffinalizeStartDifficulty()

#Sets the amount of Headers we're loading.
func setHeight*(blockchain: Blockchain, height: uint) {.raises: [ValueError].} =
    if blockchain.blocks.len != 0:
        raise newException(ValueError, "Blocks have already been added to this chain.")

    blockchain.height = height
    blockchain.headers = newSeq[BlockHeader](blockchain.height)

#Adds a Header loaded from the DB.
func load*(blockchain: Blockchain, header: BlockHeader) {.raises: [].} =
    blockchain.headers[int(header.nonce)] = header

#Adds a Block loaded from the DB.
func load*(blockchain: Blockchain, loadBlock: Block) {.raises: [].} =
    blockchain.blocks.add(loadBlock)

#Sets the Difficulty to one loaded from the DB.
func load*(blockchain: Blockchain, difficulty: Difficulty) {.raises: [].} =
    blockchain.difficulty = difficulty

#Adds a block.
proc add*(blockchain: Blockchain, newBlock: Block) {.raises: [LMDBError].} =
    inc(blockchain.height)
    blockchain.headers.add(newBlock.header)
    blockchain.blocks.add(newBlock)

    #Delete the block we're no longer caching.
    if blockchain.blocks.len > 12:
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

    if blockchain.height < 12:
        result = blockchain.blocks[int(index)]

    if index >= blockchain.height - 12:
        result = blockchain.blocks[int(index - (blockchain.height - 12))]
    else:
        result = parseBlock(blockchain.db.get("merit_" & blockchain.headers[int(index)].hash.toString()))

#Gets the last Block.
func tip*(blockchain: Blockchain): Block {.raises: [].} =
    blockchain.blocks[^1]
