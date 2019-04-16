#Errors lib.
import ../../lib/Errors

#DB Function Box object.
import ../../objects/GlobalFunctionBoxObj

#Miners object.
import objects/MinersObj

#Difficulty, Block Header, and Block libs.
import Difficulty
import BlockHeader
import Block

#Blockchain object.
import objects/BlockchainObj
export BlockchainObj

#Serialize Difficulty lib.
import ../../Network/Serialize/Merit/SerializeDifficulty

#BN lib.
import BN

#Create a new Blockchain.
proc newBlockchain*(
    db: DatabaseFunctionBox,
    genesis: string,
    blockTime: Natural,
    startDifficulty: BN
): Blockchain {.forceCheck: [].} =
    newBlockchainObj(
        db,
        genesis,
        blockTime,
        startDifficulty
    )

#Adds a block to the blockchain.
proc processBlock*(
    blockchain: var Blockchain,
    newBlock: Block
) {.forceCheck: [
    ValueError,
    IndexError,
    GapError
].} =
    #Blocks Per Month.
    let blocksPerMonth: int = 2592000 div blockchain.blockTime

    #Verify the Block Header.
    #If the nonce is off...
    if newBlock.header.nonce > blockchain.height:
        raise newException(GapError, "Missing blocks before the Block we're trying to add.")
    elif newBlock.header.nonce < blockchain.height:
        raise newException(IndexError, "Invalid nonce.")

    #If the last hash is off...
    if newBlock.header.last != blockchain.tip.header.hash:
        raise newException(ValueError, "Invalid last hash.")

    #If the time is before the last block's...
    if newBlock.header.time < blockchain.tip.header.time:
        raise newException(ValueError, "Invalid time.")

    #Verify the Block Header's Merkle Hash of the Miners matches the Block's Miners.
    if newBlock.header.miners != newBlock.miners.merkle.hash:
        raise newException(ValueError, "Invalid Miners' merkle.")

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

    #If the difficulty wasn't beat...
    if not blockchain.difficulty.verify(newBlock.header.hash):
        raise newException(ValueError, "Difficulty wasn't beat.")

    #Add the Block.
    blockchain.add(newBlock)

    #If the difficulty needs to be updated...
    if newBlock.header.nonce == blockchain.difficulty.endBlock:
        try:
            blockchain.difficulty = blockchain.calculateNextDifficulty(blocksPerPeriod)
        except IndexError as e:
            doAssert(false, "Added a Block successfully but failed to calculate the next difficulty: " & e.msg)

        try:
            blockchain.db.put("merit_difficulty", blockchain.difficulty.serialize())
        except DBWriteError as e:
            doAssert(false, "Failed to write the difficulty to the DB: " & e.msg)
