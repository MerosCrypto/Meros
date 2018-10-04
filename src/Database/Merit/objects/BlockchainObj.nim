#Errors lib.
import ../../../lib/Errors

#Numerical libs.
import BN
import ../../../lib/Base

#Time lib.
import ../../../lib/Time

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
        #Block time.
        blockTime* {.final.}: int
        #Blocks per month. Helper piece of data.
        blocksPerMonth* {.final.}: int

        #Height. BN for compatibility.
        height*: BN
        #seq of all the blocks.
        blocks*: seq[Block]
        #seq of all the difficulties.
        difficulties*: seq[Difficulty]

#Create a Blockchain object.
proc newBlockchainObj*(
    genesis: string,
    blockTime: int,
    blocksPerMonth: int,
    startDifficulty: BN
): Blockchain {.raises: [ValueError, ArgonError].} =
    result = Blockchain(
        blockTime: blockTime,
        blocksPerMonth: blocksPerMonth,

        height: newBN(),
        blocks: @[
            newStartBlock(genesis)
        ],
        difficulties: @[
            newDifficultyObj(
                BNNums.ZERO,
                newBN(1),
                startDifficulty
            )
        ]
    )

proc add*(blockchain: Blockchain, newBlock: Block) {.raises: [].} =
    inc(blockchain.height)
    blockchain.blocks.add(newBlock)

proc add*(blockchain: Blockchain, difficulty: Difficulty) {.raises: [].} =
    blockchain.difficulties.add(difficulty)
