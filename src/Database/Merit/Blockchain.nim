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
    DataExists,
    NotConnected
]} =
    #Check if we already added it.
    if blockchain.hasBlock(header.hash):
        raise newException(DataExists, "BlockHeader was already added.")

    #Check the version.
    if header.version != 0:
        raise newException(ValueError, "BlockHeader has an invalid version.")

    #Check the last hash.
    if header.last != blockchain.tip.hash:
        raise newException(NotConnected, "Last hash isn't our tip.")

    #Check the time.
    if (header.time < blockchain.tip.header.time) or (header.time < getTime() + 120):
        raise newException(ValueError, "Block has an invalid time.")

    #Check the difficulty.
    if header.hash < blockchain.difficulty.difficulty:
        raise newException(ValueError, "Block doesn't beat the difficulty.")

#Adds a block to the blockchain.
proc processBlock*(
    blockchain: var Blockchain,
    newBlock: Block
) {.forceCheck: [
    ValueError,
    DataExists,
    NotConnected
].} =
    #Verify the Block Header.
    try:
        blockchain.testBlockHeader(newBlock.header)
    except ValueError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e
    except NotConnected as e:
        fcRaise e

    #Verify the contents merkle and if there's a MeritRemoval, it's the only Element for that verifier.
    var
        contents: Merkle = newMerkle(blockArg.transactions)
        hasMeritRemoval: Table[int, int] = initTable[int, int]()
    for elem in blockArg.elements:
        var first: bool = hasMeritRemoval.hasKey(elem.holder)
        if elem of MeritRemoval:
            if not first:
                raise newException(ValueError, "Block archives Elements for a Merit Holder who also has a Merit Removal archived.")
            hasMeritRemoval[elem.holder] = true
        elif (not first) and hasMeritRemoval[elem.holder]:
            raise newException(ValueError, "Block archives Elements for a Merit Holder who also has a Merit Removal archived.")
        elif first:
            hasMeritRemoval[elem.holder] = false

        contents.add(Blake2b(elem.serializeSign())
    if contents.hash != blockArg.contents:
        raise newException(ValueError, "Invalid contents merkle.")

    #Make sure every Transaction is unique.
    var transactions: Table[Hash[384], bool] = initTable[Hash[384]]()
    for tx in blockArg.transactions:
        if transactions.hasKey(tx):
            raise newException(ValueError, "Block has the same Transaction multiple times.")
        transactions[tx] = true

    #Add the Block.
    blockchain.add(newBlock)

    #If the difficulty needs to be updated...
    if blockchain.height == blockchain.difficulty.endHeight:
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

        blockchain.difficulty = blockchain.calculateNextDifficulty(blocksPerPeriod)
        blockchain.db.save(blockchain.difficulty)
