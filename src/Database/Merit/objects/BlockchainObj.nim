#Numerical libs.
import BN
import ../../../lib/Base

#Time lib.
import ../../../lib/Time

#Block and Difficulty objects.
import BlockObj
import DifficultyObj

#SetOnce lib.
import SetOnce

#Blockchain object.
type Blockchain* = ref object of RootObj
    #Height. BN for compatibility.
    height*: BN
    #seq of all the blocks.
    blocks*: seq[Block]
    #seq of all the difficulties.
    difficulties*: seq[Difficulty]

#Create a Blockchain object.
proc newBlockchainObj*(genesis: string): Blockchain {.raises: [ValueError].} =
    let creation: BN = getTime()

    result = Blockchain(
        height: newBN(),
        blocks: @[
            newStartBlock(genesis)
        ],
        difficulties: @[
            newDifficultyObj(
                BNNums.ZERO,
                newBN(6),
                "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA".toBN(16)
            )
        ]
    )

proc add*(blockchain: Blockchain, newBlock: Block) {.raises: [].} =
    inc(blockchain.height)
    blockchain.blocks.add(newBlock)

proc add*(blockchain: Blockchain, difficulty: Difficulty) {.raises: [].} =
    blockchain.difficulties.add(difficulty)
