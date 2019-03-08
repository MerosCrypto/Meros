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

#Parse Block lib.
import ../../../Network/Serialize/Merit/ParseBlock

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Blockchain object.
finalsd:
    type Blockchain* = ref object of RootObj
        #DB Function Box.
        db: DatabaseFunctionBox

        #Block time (part of the chain params).
        blockTime* {.final.}: uint

        #Height.
        height*: uint
        #seq of every Blok Header.
        headers: seq[BlockHeader]
        #seq of all the Blocks in RAM.
        blocks: seq[Block]

        #seq of all the Difficulties.
        difficulties*: seq[Difficulty]

#Create a Blockchain object.
proc newBlockchainObj*(
    genesis: string,
    blockTime: uint,
    startDifficulty: BN,
    db: DatabaseFunctionBox
): Blockchain {.raises: [ValueError, ArgonError].} =
    result = Blockchain(
        db: db,

        blockTime: blockTime,

        height: 1,
        headers: @[],
        blocks: @[
            newBlockObj(
                0,
                genesis.pad(64).toArgonHash(),
                nil,
                @[],
                @[],
                0,
                0
            )
        ],

        difficulties: @[
            newDifficultyObj(
                0,
                1,
                startDifficulty
            )
        ]
    )
    result.ffinalizeBlockTime()

#Adds a block.
func add*(blockchain: Blockchain, newBlock: Block) {.raises: [].} =
    inc(blockchain.height)
    blockchain.headers.add(newBlock.header)
    blockchain.blocks.add(newBlock)

    #Override for our tests.
    if not blockchain.db.isNil:
        if blockchain.blocks.len > 12:
            blockchain.blocks.delete(0)

#Adds a Difficulty.
func add*(blockchain: Blockchain, difficulty: Difficulty) {.raises: [].} =
    blockchain.difficulties.add(difficulty)

#Block getter.
proc `[]`*(blockchain: Blockchain, index: uint): Block {.raises: [
    ValueError,
    ArgonError,
    BLSError,
    LMDBError,
    FinalAttributeError
].} =
    #Override for our tests.
    if blockchain.db.isNil:
        return blockchain.blocks[int(index)]

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
