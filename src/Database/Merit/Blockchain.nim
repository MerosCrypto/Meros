#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Numerical libs.
import BN
import ../../lib/Base

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
    startDifficulty: BN
): Blockchain {.raises: [ValueError, ArgonError].} =
    newBlockchainObj(
        genesis,
        blockTime,
        startDifficulty
    )

#Adds a block to the blockchain.
proc addBlock*(blockchain: Blockchain, newBlock: Block): bool {.raises: [ValueError].} =
    #Result is set to true for if nothing goes wrong.
    result = true

    let
        #Blocks Per Month.
        blocksPerMonth: int = 2592000 div blockchain.blockTime
        #Grab the Blocks.
        blocks: seq[Block] = blockchain.blocks

    #If the last hash is off...
    if newBlock.last != blocks[^1].argon:
        return false

    #If the nonce is off...
    if newBlock.nonce != blockchain.height + 1:
        return false

    #If the time is before the last block's...
    if newBlock.time < blocks[^1].time:
        return false

    #Set the period length.
    var blocksPerPeriod: int
    #If we're in the first month, the period length is one block.
    if blockchain.height < blocksPerMonth:
        blocksPerPeriod = 1
    #If we're in the first three months, the period length is one hour.
    elif blockchain.height < blocksPerMonth * 3:
        blocksPerPeriod = 6
    #If we're in the first six months, the period length is six hours.
    elif blockchain.height < blocksPerMonth * 6:
        blocksPerPeriod = 36
    #If we're in the first year, the period length is twelve hours.
    elif blockchain.height < blocksPerMonth * 12:
        blocksPerPeriod = 72
    #Else, if it's over an year, the period length is a day.
    else:
        blocksPerPeriod = 144

    #If the difficulty needs to be updated...
    if blockchain.difficulties[^1].endBlock <= newBlock.nonce:
        blockchain.add(
            calculateNextDifficulty(
                blockchain.blocks,
                blockchain.difficulties,
                uint(blockchain.blockTime * blocksPerPeriod),
                blocksPerPeriod
            )
        )

    #If the difficulty wasn't beat...
    if not blockchain.difficulties[^1].verifyDifficulty(newBlock):
        return false

    blockchain.add(newBlock)
