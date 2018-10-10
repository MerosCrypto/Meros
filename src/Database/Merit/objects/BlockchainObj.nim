#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Numerical libs.
import BN
import ../../../lib/Base

#Block and Difficulty objects.
import BlockObj
import DifficultyObj

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
        #seq of all the blocks.
        blocks*: seq[Block]
        #seq of all the difficulties.
        difficulties*: seq[Difficulty]

#Create a Blockchain object.
proc newBlockchainObj*(
    genesis: string,
    blockTime: uint,
    startDifficulty: BN
): Blockchain {.raises: [ValueError, ArgonError].} =
    Blockchain(
        blockTime: blockTime,

        height: 0,
        blocks: @[
            newStartBlock(genesis)
        ],
        difficulties: @[
            newDifficultyObj(
                0,
                1,
                startDifficulty
            )
        ]
    )

func add*(blockchain: Blockchain, newBlock: Block) {.raises: [].} =
    inc(blockchain.height)
    blockchain.blocks.add(newBlock)

func add*(blockchain: Blockchain, difficulty: Difficulty) {.raises: [].} =
    blockchain.difficulties.add(difficulty)
