#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#BN lib.
import BN

#BLS lib.
import ../../lib/BLS

#Miners object.
import objects/MinersObj

#Difficulty and Block libs.
import Difficulty
import Block

#Blockchain object.
import objects/BlockchainObj
export BlockchainObj

#Create a new Blockchain.
proc newBlockchain*(
    genesis: string,
    blockTime: uint,
    startDifficulty: BN
): Blockchain {.raises: [ValueError, ArgonError, BLSError].} =
    newBlockchainObj(
        genesis,
        blockTime,
        startDifficulty
    )

#Adds a block to the blockchain.
proc processBlock*(
    blockchain: Blockchain,
    newBlock: Block
): bool {.raises: [ValueError].} =
    #Result is set to true for if nothing goes wrong.
    result = true

    let
        #Blocks Per Month.
        blocksPerMonth: uint = uint(2592000) div blockchain.blockTime
        #Grab the Blocks.
        blocks: seq[Block] = blockchain.blocks

    #Verify the Block Header.
    #If the nonce is off...
    if newBlock.header.nonce != blockchain.height:
        return false

    #If the last hash is off...
    if newBlock.header.last != blocks[^1].hash:
        return false

    #If the time is before the last block's...
    if newBlock.header.time < blocks[^1].header.time:
        return false

    #Verify the Block Header's Merkle Hash of the Miners matches the Block's Miners.
    if newBlock.header.miners != newBlock.miners.calculateMerkle():
        return false

    #Verify the Block itself.
    #Verify the Miners.
    var total: uint = 0
    if (newBlock.miners.len < 1) or (100 < newBlock.miners.len):
        raise newException(ValueError, "Invalid Miners quantity.")
    for miner in newBlock.miners:
        total += miner.amount
        if (miner.amount < 1) or (uint(100) < miner.amount):
            raise newException(ValueError, "Invalid Miner amount.")
    if total != 100:
        raise newException(ValueError, "Invalid total Miner amount.")

    #Set the period length.
    var blocksPerPeriod: uint
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
    if blockchain.difficulties[^1].endBlock <= newBlock.header.nonce:
        blockchain.add(
            calculateNextDifficulty(
                blockchain.blocks,
                blockchain.difficulties,
                blockchain.blockTime * blocksPerPeriod,
                blocksPerPeriod
            )
        )

    #If the difficulty wasn't beat...
    if not blockchain.difficulties[^1].verifyDifficulty(newBlock):
        return false

    #Add the Block.
    blockchain.add(newBlock)
