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

    var blocksPerNextDifficulty : int = 1 # every block

    # tests for a month to three months
    if blockchain.height >= newBN($(30 * 24 * 6)) and blockchain.height < newBN($(90 * 24 * 6)):
        blocksPerNextDifficulty = 6 #one hour

    # tests for 3 month to 6 months
    if blockchain.height >= newBN($(90 * 24 * 6)) and blockchain.height < newBN($(180 * 24 * 6)):
        blocksPerNextDifficulty = 36 # six hours

    # tests for 6 month to a year
    if blockchain.height >= newBN($(180 * 24 * 6)) and blockchain.height < newBN($(365 * 24 * 6)):
        blocksPerNextDifficulty = 72 # every 12  hours

    # tests for year and on
    if blockchain.height >= newBN($(365 * 24 * 6)):
        blocksPerNextDifficulty = 144 # every day

    #If the difficulty needs to be updated...
    if difficulty.endBlock <= newBlock.nonce:
        difficulty = calculateNextDifficulty(blockchain.blocks, blockchain.difficulties, blocksPerNextDifficulty)
        blockchain.add(difficulty)

    #If the difficulty wasn't beat...
    if not difficulty.verifyDifficulty(newBlock):
        return false

    blockchain.add(newBlock)
