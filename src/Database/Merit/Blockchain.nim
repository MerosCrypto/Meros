#Number libs.
import ../../lib/BN
import ../../lib/Base

#Time lib.
import ../../lib/Time

#Merkle, Block, and Difficulty libs.
import Merkle
import Block
import Difficulty

#Blockchain object.
import objects/BlockchainObj
export BlockchainObj

#Create a new Blockchain.
proc newBlockchain*(genesis: string): Blockchain {.raises: [ValueError, AssertionError].} =
    #Set the current time as the time of creation.
    let creation: BN = getTime()

    #Init the object.
    result = newBlockchainObj(genesis)

#Adds a block to the blockchain.
proc addBlock*(blockchain: Blockchain, newBlock: Block): bool {.raises: [AssertionError, Exception].} =
    #Result is set to true for if nothing goes wrong.
    result = true

    let
        blocks: seq[Block] = blockchain.getBlocks()
        lastBlock: Block = blocks[blocks.len - 1]
        difficulties: seq[Difficulty] = blockchain.getDifficulties()
        lastDifficulty: Difficulty = difficulties[difficulties.len - 1]

    #If the last hash is off...
    if lastBlock.getArgon() != newBlock.getLast():
        result = false
        return

    #If the nonce is off...
    if blockchain.getHeight() + BNNums.ONE != newBlock.getNonce():
        result = false
        return

    #If the time is before the last block's...
    if newBlock.getTime() < lastBlock.getTime():
        result = false
        return

    #If the time is ahead of 20 minutes from now...
    if (getTime() + newBN($(20*60))) < newBlock.getTime():
        result = false
        return

    #Generate difficulties so we can test the block against the latest difficulty.
    while lastDifficulty.getEnd() < newBlock.getTime():
        blockchain.add(calculateNextDifficulty(blockchain.getBlocks(), blockchain.getDifficulties(), 60, 6))

    #If the difficulty wasn't beat...
    if not lastDifficulty.verifyDifficulty(newBlock):
        result = false
        return

    blockchain.add(newBlock)
