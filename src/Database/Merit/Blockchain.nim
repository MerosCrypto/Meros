#Numerical libs.
import BN
import ../../lib/Base

#Time lib.
import ../../lib/Time

#Merkle lib.
import ../../lib/Merkle

#Block, and Difficulty libs.
import Block
import Difficulty

#Blockchain object.
import objects/BlockchainObj
export BlockchainObj

#SetOnce lib.
import SetOnce

#Create a new Blockchain.
proc newBlockchain*(genesis: string): Blockchain {.raises: [ValueError].} =
    #Set the current time as the time of creation.
    let creation: BN = getTime()

    #Init the object.
    result = newBlockchainObj(genesis)

#Adds a block to the blockchain.
proc addBlock*(blockchain: Blockchain, newBlock: Block): bool {.raises: [Exception].} =
    #Result is set to true for if nothing goes wrong.
    result = true

    let
        blocks: seq[Block] = blockchain.blocks
        lastBlock: Block = blocks[blocks.len - 1]

    #If the last hash is off...
    if lastBlock.argon != newBlock.last:
        return false

    #If the nonce is off...
    if blockchain.height + BNNums.ONE != newBlock.nonce:
        return false

    #If the time is before the last block's...
    if newBlock.time < lastBlock.time:
        return false

    #If the time is ahead of 20 minutes from now...
    if (getTime() + newBN($(20*60))) < newBlock.time:
        return false

    #Get the difficulties.
    var
        difficulties: seq[Difficulty] = blockchain.difficulties
        difficulty: Difficulty = difficulties[difficulties.len - 1]

    #Generate difficulties so we can test the block against the latest difficulty.
    while difficulty.endTime < newBlock.time:
        difficulty = calculateNextDifficulty(blockchain.blocks, blockchain.difficulties, 10, 6)
        blockchain.add(difficulty)

    #If the difficulty wasn't beat...
    if not difficulty.verifyDifficulty(newBlock):
        return false

    blockchain.add(newBlock)
