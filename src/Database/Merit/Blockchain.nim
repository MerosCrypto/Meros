#Errors lib.
import ../../lib/Errors

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

#Create a new Blockchain.
proc newBlockchain*(
    genesis: string,
    blockTime: int,
    blocksPerMonth: int,
    startDifficulty: BN
): Blockchain {.raises: [ValueError, ArgonError].} =
    newBlockchainObj(
        genesis,
        blockTime,
        blocksPerMonth,
        startDifficulty
    )

#Adds a block to the blockchain.
proc addBlock*(blockchain: Blockchain, newBlock: Block): bool {.raises: [ValueError].} =
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
    if (getTime() + 1200) < newBlock.time:
        return false

    var
        #Get the difficulties.
        difficulties: seq[Difficulty] = blockchain.difficulties
        difficulty: Difficulty = difficulties[difficulties.len - 1]
        #Store the blocks per period in an int.
        blocksPerPeriod: int

    #Set the period length.
    #If we're in the first month, the period length is one block.
    if blockchain.height < newBN(blockchain.blocksPerMonth):
        blocksPerPeriod = 1
    #If we're in the first three months, the period length is one hour.
    elif blockchain.height < newBN(blockchain.blocksPerMonth * 3):
        blocksPerPeriod = 6
    #If we're in the first six months, the period length is six hours.
    elif blockchain.height < newBN(blockchain.blocksPerMonth * 6):
        blocksPerPeriod = 36
    #If we're in the first year, the period length is twelve hours.
    elif blockchain.height < newBN(blockchain.blocksPerMonth * 12):
        blocksPerPeriod = 72
    #Else, if it's over an year, the period length is a day.
    else:
        blocksPerPeriod = 144

    #If the difficulty needs to be updated...
    if difficulty.endBlock <= newBlock.nonce:
        difficulty = calculateNextDifficulty(
            blockchain.blocks,
            blockchain.difficulties,
            blockchain.blockTime * blocksPerPeriod,
            blocksPerPeriod
        )
        blockchain.add(difficulty)

    #If the difficulty wasn't beat...
    if not difficulty.verifyDifficulty(newBlock):
        return false

    blockchain.add(newBlock)
