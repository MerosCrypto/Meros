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

#Element Serialization lib.
import ../../Network/Serialize/Consensus/SerializeElement

#Merit DB lib.
import ../Filesystem/DB/MeritDB

#Difficulty, Block Header, and Block libs.
import Difficulty
import BlockHeader
import Block

#State lib.
import State

#Blockchain object.
import objects/BlockchainObj
export BlockchainObj

#Sets standard lib.
import sets

#Tables standard lib.
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
        raise newLoggedException(ValueError, "Block doesn't beat the difficulty.")

    #Check the version.
    if header.version != 0:
        raise newLoggedException(ValueError, "BlockHeader has an invalid version.")

    #Check the last hash.
    if header.last != blockchain.tail.header.hash:
        raise newLoggedException(NotConnected, "Last hash isn't our tip.")

    #Check significant.
    if (header.significant == 0) or (header.significant > uint16(26280)):
        raise newLoggedException(ValueError, "Invalid significant.")

    var key: BLSPublicKey
    if header.newMiner:
        #Check a miner with a nickname isn't being marked as new.
        if blockchain.miners.hasKey(header.minerKey):
            raise newLoggedException(ValueError, "Header marks a miner with a nickname as new.")

        #Make sure the key isn't infinite.
        if header.minerKey.isInf:
            raise newLoggedException(ValueError, "Header has an infinite miner key.")

        #Grab the key.
        key = header.minerKey
    else:
        #Make sure the nick is valid.
        if header.minerNick >= uint16(lookup.len):
            raise newLoggedException(ValueError, "Header has an invalid nickname.")

        key = lookup[header.minerNick]

    #Check the time.
    if (header.time < blockchain.tail.header.time) or (header.time > getTime() + 30):
        raise newLoggedException(ValueError, "Block has an invalid time.")

    #Check the signature.
    try:
        if not header.signature.verify(newBLSAggregationInfo(key, header.interimHash)):
            raise newLoggedException(ValueError, "Block has an invalid signature.")
    except BLSError as e:
        panic("Failed to verify a BlockHeader's signature: " & e.msg)

#Adds a Block to the Blockchain.
proc processBlock*(
    blockchain: var Blockchain,
    newBlock: Block
) {.forceCheck: [].} =
    logDebug "Blockchain processing Block", hash = newBlock.header.hash

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
    blockchain.db.save(newBlock.header.hash, blockchain.difficulty)

#Revert the Blockchain to a certain height.
proc revert*(
    blockchain: var Blockchain,
    state: var State,
    height: int
) {.forceCheck: [].} =
    #Revert the State.
    state.revert(blockchain, height)

    #Miners we changed the Merit of.
    var changedMerit: HashSet[uint16] = initHashSet[uint16]()

    #Revert the Blocks.
    for b in countdown(blockchain.height - 1, height):
        try:
            #If this Block had a new miner, delete it.
            if blockchain[b].header.newMiner:
                blockchain.miners.del(blockchain[b].header.minerKey)
                blockchain.db.deleteHolder()
                changedMerit.excl(uint16(blockchain.miners.len))
            #Else, mark that this miner's Merit changed.
            else:
                changedMerit.incl(uint16(blockchain[b].header.minerNick))

            #If this Block had a Merit Removal, mark the affected holder in changedMerit.
            for elem in blockchain[b].body.elements:
                if elem of MeritRemoval:
                    changedMerit.incl(cast[MeritRemoval](elem).holder)
        except IndexError as e:
            panic("Couldn't grab the Block we're reverting past: " & e.msg)

        if b > state.deadBlocks:
            var deadBlock: Block
            try:
                deadBlock = blockchain[b - state.deadBlocks]
            except IndexError as e:
                panic("Couldn't grab the Block whose Merit died when the Block we're reverting past was added: " & e.msg)

            if deadBlock.header.newMiner:
                try:
                    changedMerit.incl(blockchain.miners[deadBlock.header.minerKey])
                except KeyError as e:
                    panic("Couldn't get the nickname of a miner who's Merit died: " & e.msg)
            else:
                changedMerit.incl(deadBlock.header.minerNick)

            for elem in deadBlock.body.elements:
                if elem of MeritRemoval:
                    changedMerit.incl(cast[MeritRemoval](elem).holder)

        #Delete the Block.
        try:
            blockchain.db.deleteBlock(b, blockchain[b].body.elements)
        except IndexError:
            panic("Couldn't get a Block's Elements before we deleted it.")
        #Rewind the cache.
        blockchain.rewindCache()

        #Decrement the height.
        dec(blockchain.height)

    #Save the reverted to tip.
    blockchain.db.saveTip(blockchain.tail.header.hash)

    #Save the reverted to height.
    blockchain.db.saveHeight(blockchain.height)

    #Load the reverted to difficulty.
    try:
        blockchain.difficulty = blockchain.db.loadDifficulty(blockchain.tail.header.hash)
    except DBReadError as e:
        panic("Couldn't load the difficulty of the Block we reverted to: " & e.msg)

    #Update the RandomX keys.
    var
        currentKeyHeight: int = blockchain.height - 64
        blockUsedAsKey: int = (currentKeyHeight - (currentKeyHeight mod 2048)) - 1
        blockUsedAsUpcomingKey: int = (blockchain.height - (blockchain.height mod 2048)) - 1
        currentKey: string
    if blockUsedAsKey == -1:
        currentKey = blockchain.genesis.toString()
    else:
        try:
            currentKey = blockchain[blockUsedAsKey].header.hash.toString()
        except IndexError as e:
            panic("Couldn't grab the Block used as the current RandomX key: " & e.msg)

    #Rebuild the RandomX cache if needed.
    if currentKey != blockchain.cacheKey:
        blockchain.cacheKey = currentKey
        setRandomXKey(blockchain.cacheKey)
        blockchain.db.saveKey(blockchain.cacheKey)

    if blockUsedAsUpcomingKey == -1:
        blockchain.db.saveUpcomingKey(blockchain.genesis.toString())
    else:
        try:
            blockchain.db.saveUpcomingKey(blockchain[blockUsedAsUpcomingKey].header.hash.toString())
        except IndexError as e:
            panic("Couldn't grab the Block used as the upcoming RandomX key: " & e.msg)

    #Update the Merit of everyone who had their Merit changed.
    for holder in changedMerit:
        blockchain.db.saveMerit(holder, state[holder, state.processedBlocks])
