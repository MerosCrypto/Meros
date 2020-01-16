#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#VerificationPacket and MeritRemoval objects.
import ../Consensus/Elements/objects/VerificationPacketObj
import ../Consensus/Elements/objects/MeritRemovalObj

#Serialization libs.
import ../../Network/Serialize/Merit/SerializeBlockHeader
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
    startDifficulty: Hash[256]
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
    lookup: seq[BLSPublicKey],
    header: BlockHeader
) {.forceCheck: [
    ValueError,
    NotConnected
].} =
    #Check the difficulty.
    if header.hash < blockchain.difficulty.difficulty:
        raise newException(ValueError, "Block doesn't beat the difficulty.")

    #Check the version.
    if header.version != 0:
        raise newException(ValueError, "BlockHeader has an invalid version.")

    #Check the last hash.
    if header.last != blockchain.tail.header.hash:
        raise newException(NotConnected, "Last hash isn't our tip.")

    #Check significant.
    if (header.significant == 0) or (header.significant > uint16(26280)):
        raise newException(ValueError, "Invalid significant.")

    var key: BLSPublicKey
    if header.newMiner:
        #Check a miner with a nickname isn't being marked as new.
        if blockchain.miners.hasKey(header.minerKey):
            raise newException(ValueError, "Header marks a miner with a nickname as new.")

        #Make sure the key isn't infinite.
        if header.minerKey.isInf:
            raise newException(ValueError, "Header has an infinite miner key.")

        #Grab the key.
        key = header.minerKey
    else:
        #Make sure the nick is valid.
        if header.minerNick >= uint16(lookup.len):
            raise newException(ValueError, "Header has an invalid nickname.")

        key = lookup[header.minerNick]

    #Check the time.
    if (header.time < blockchain.tail.header.time) or (header.time > getTime() + 30):
        raise newException(ValueError, "Block has an invalid time.")

    #Check the signature.
    try:
        if not header.signature.verify(newBLSAggregationInfo(key, RandomX(header.serializeHash()).toString())):
            raise newException(ValueError, "Block has an invalid signature.")
    except BLSError as e:
        doAssert(false, "Failed to verify a BlockHeader's signature: " & e.msg)

#Adds a block to the blockchain.
proc processBlock*(
    blockchain: var Blockchain,
    newBlock: Block
) {.forceCheck: [].} =
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
