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

const
    #Block time in seconds.
    BLOCK_TIME: int = 600
    #Constant of the blocks per month.
    BLOCKS_PER_MONTH: int = 4320

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
    if (getTime() + newBN(1200)) < newBlock.time:
        return false

    var
        #Get the difficulties.
        difficulties: seq[Difficulty] = blockchain.difficulties
        difficulty: Difficulty = difficulties[difficulties.len - 1]
        #Store the blocks per period in an int.
        blocksPerPeriod: int

    #Set the period length.
    #If we're in the first month, the period length is one block.
    if blockchain.height < newBN(BLOCKS_PER_MONTH):
        blocksPerPeriod = 1
    #If we're in the first three months, the period length is one hour.
    elif blockchain.height < newBN(BLOCKS_PER_MONTH * 3):
        blocksPerPeriod = 6
    #If we're in the first six months, the period length is six hours.
    elif blockchain.height < newBN(BLOCKS_PER_MONTH * 6):
        blocksPerPeriod = 36
    #If we're in the first year, the period length is twelve hours.
    elif blockchain.height < newBN(BLOCKS_PER_MONTH * 12):
        blocksPerPeriod = 72
    #Else, if it's over an year, the period length is a day.
    else:
        blocksPerPeriod = 144

    #If the difficulty needs to be updated...
    if difficulty.endBlock <= newBlock.nonce:
        difficulty = calculateNextDifficulty(blockchain.blocks, blockchain.difficulties, BLOCK_TIME * blocksPerPeriod, blocksPerPeriod)
        blockchain.add(difficulty)

    #If the difficulty wasn't beat...
    if not difficulty.verifyDifficulty(newBlock):
        return false

    blockchain.add(newBlock)
