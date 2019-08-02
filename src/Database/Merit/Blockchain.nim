#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Merit DB lib.
import ../Filesystem/DB/MeritDB

#MeritHolderRecord object.
import ../common/objects/MeritHolderRecordObj

#Miners object.
import objects/MinersObj

#Difficulty, Block Header, and Block libs.
import Difficulty
import BlockHeader
import Block

#Blockchain object.
import objects/BlockchainObj
export BlockchainObj

#Tables lib.
import tables

#Create a new Blockchain.
proc newBlockchain*(
    db: DB,
    genesis: string,
    blockTime: int,
    startDifficulty: Hash[384]
): Blockchain {.forceCheck: [].} =
    newBlockchainObj(
        db,
        genesis,
        blockTime,
        startDifficulty
    )

#Test a BlockHeader.
proc testBlockHeader*(
    blockchain: Blockchain,
    header: BlockHeader
) {.forceCheck: [
    ValueError,
    GapError,
    UncleBlock,
    DataExists
]} =
    #If the nonce is off...
    if header.nonce > blockchain.height:
        raise newException(GapError, "Missing blocks before the Block we're trying to add.")
    elif header.nonce < blockchain.height:
        if blockchain.headers[header.nonce].hash == header.hash:
            raise newException(DataExists, "BlockHeader was already added.")
        else:
            raise newException(UncleBlock, "Old BlockHeader with a different hash than our BlockHeader at that nonce.")

    #If the last hash is off...
    if header.last != blockchain.tip.hash:
        raise newException(ValueError, "Invalid last hash.")

    #If the time is before the last block's...
    if header.time < blockchain.tip.header.time:
        raise newException(ValueError, "Invalid time.")

#Adds a block to the blockchain.
proc processBlock*(
    blockchain: var Blockchain,
    newBlock: Block
) {.forceCheck: [
    ValueError,
    GapError,
    DataExists
].} =
    #Verify the Block Header.
    try:
        blockchain.testBlockHeader(newBlock.header)
    except ValueError as e:
        fcRaise e
    except GapError as e:
        fcRaise e
    except UncleBlock as e:
        raise newException(ValueError, e.msg)
    except DataExists as e:
        fcRaise e

    #Verify the Block Header's Merkle Hash of the Miners matches the Block's Miners.
    if newBlock.header.miners != newBlock.miners.merkle.hash:
        raise newException(ValueError, "Invalid Miners' merkle.")

    #Verify no MeritHolder has multiple Records.
    var
        holders: Table[string, bool] = initTable[string, bool]()
        holder: string
    for record in newBlock.records:
        holder = record.key.toString()
        try:
            if holders[holder]:
                raise newException(ValueError, "One MeritHolder has two Records.")
        except KeyError:
            discard
        holders[holder] = true

    #Verify the miners.
    if (newBlock.miners.miners.len < 1) or (100 < newBlock.miners.miners.len):
        raise newException(ValueError, "Invalid Miners quantity.")
    var total: int = 0
    for miner in newBlock.miners.miners:
        if (miner.amount < 1) or (100 < miner.amount):
            raise newException(ValueError, "Invalid Miner amount.")
        total += miner.amount
    if total != 100:
        raise newException(ValueError, "Invalid total Miner amount.")

    #If the difficulty wasn't beat...
    if not blockchain.difficulty.verify(newBlock.hash):
        raise newException(ValueError, "Difficulty wasn't beat.")

    #Add the Block.
    blockchain.add(newBlock)

    #If the difficulty needs to be updated...
    if newBlock.nonce == blockchain.difficulty.endBlock:
        var
            #Blocks Per Month.
            blocksPerMonth: int = 2592000 div blockchain.blockTime
            #Period Length.
            blocksPerPeriod: int
        #Set the period length.
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

        try:
            blockchain.difficulty = blockchain.calculateNextDifficulty(blocksPerPeriod)
        except IndexError as e:
            doAssert(false, "Added a Block successfully but failed to calculate the next difficulty: " & e.msg)

        blockchain.db.save(blockchain.difficulty)
