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

#Difficulty, BlockHeader, and Block objects.
import DifficultyObj
import BlockHeaderObj
import BlockObj

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Blockchain object.
finalsd:
    type Blockchain* = ref object of RootObj
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
    startDifficulty: BN
): Blockchain {.raises: [ValueError, ArgonError].} =
    result = Blockchain(
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
    blockchain.blocks.add(newBlock)

#Adds a Difficulty.
func add*(blockchain: Blockchain, difficulty: Difficulty) {.raises: [].} =
    blockchain.difficulties.add(difficulty)

#Block getter.
proc `[]`*(blockchain: Blockchain, index: uint): Block {.raises: [].} =
    blockchain.blocks[int(index)]

#Gets the last Block.
func tip*(blockchain: Blockchain): Block {.raises: [].} =
    blockchain.blocks[^1]
