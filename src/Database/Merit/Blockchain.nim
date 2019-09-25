#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Merkle lib.
import ../../lib/Merkle

#MinerWallet lib.
import ../../Wallet/MinerWallet

#MeritRemoval object.
import ../Consensus/objects/MeritRemovalObj

#Serialize Element lib.
import ../../Network/Serialize/Consensus/SerializeElement

#Merit DB lib.
import ../Filesystem/DB/MeritDB

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
].} =
    #Check the difficulty.
    if header.hash < blockchain.difficulty.difficulty:
        raise newException(ValueError, "Block doesn't beat the difficulty.")

    #Check if we already added it.
    if blockchain.hasBlock(header.hash):
        raise newException(DataExists, "BlockHeader was already added.")

    #Check the version.
    if header.version != 0:
        raise newException(ValueError, "BlockHeader has an invalid version.")

    #Check the last hash.
    if header.last != blockchain.tip.hash:
        raise newException(NotConnected, "Last hash isn't our tip.")

    #Check a miner with a nickname isn't being marked as new.
    if header.newMiner and blockchain.miners.hasKey(header.minerKey):
        raise newException(ValueError, "Header marks a miner with a nickname as new.")

    #Check the time.
    if (header.time < blockchain.tip.header.time) or (header.time > getTime() + 120):
        raise newException(ValueError, "Block has an invalid time.")

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
        contents: Merkle = newMerkle(newBlock.body.transactions)
        hasMeritRemoval: Table[int, bool] = initTable[int, bool]()
    try:
        for elem in newBlock.body.elements:
            var first: bool = hasMeritRemoval.hasKey(elem.holder)
            if elem of MeritRemoval:
                if not first:
                    raise newException(ValueError, "Block archives Elements for a Merit Holder who also has a Merit Removal archived.")
                hasMeritRemoval[elem.holder] = true
            elif (not first) and hasMeritRemoval[elem.holder]:
                raise newException(ValueError, "Block archives Elements for a Merit Holder who also has a Merit Removal archived.")
            elif first:
                hasMeritRemoval[elem.holder] = false

            contents.add(Blake384(elem.serializeSign()))
    except KeyError as e:
        doAssert(false, "Couldn't get a key we're guaranteed to have if we access it: " & e.msg)
    if contents.hash != newBlock.header.contents:
        raise newException(ValueError, "Invalid contents merkle.")

    #Make sure every Transaction is unique.
    var transactions: Table[Hash[384], bool] = initTable[Hash[384], bool]()
    for tx in newBlock.body.transactions:
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
