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

#StInt external lib.
import stint

#Sets standard lib.
import sets

#Tables standard lib.
import tables

#Create a new Blockchain.
proc newBlockchain*(
    db: DB,
    genesis: string,
    blockTime: int,
    initialDifficulty: uint64
): Blockchain {.inline, forceCheck: [].} =
    newBlockchainObj(
        db,
        genesis,
        blockTime,
        initialDifficulty
    )

#Test a BlockHeader.
proc testBlockHeader*(
    miners: Table[BLSPublicKey, uint16],
    lookup: seq[BLSPublicKey],
    previous: BlockHeader,
    difficulty: uint64,
    header: BlockHeader
) {.forceCheck: [
    ValueError
].} =
    #Check the difficulty.
    if header.hash.overflows(difficulty):
        raise newLoggedException(ValueError, "Block doesn't beat the difficulty.")

    #Check the version.
    if header.version != 0:
        raise newLoggedException(ValueError, "BlockHeader has an invalid version.")

    #Check significant.
    if (header.significant == 0) or (header.significant > uint16(26280)):
        raise newLoggedException(ValueError, "Invalid significant.")

    var key: BLSPublicKey
    if header.newMiner:
        #Check a miner with a nickname isn't being marked as new.
        if miners.hasKey(header.minerKey):
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
    if (header.time <= previous.time) or (header.time > getTime() + 30):
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

    #Calculate the next difficulty.
    var
        windowLength: int = calculateWindowLength(blockchain.height)
        time: uint32
    if windowLength != 0:
        try:
            time = blockchain.tail.header.time - blockchain[blockchain.height - windowLength].header.time
        except IndexError as e:
            panic("Couldn't get Block " & $(blockchain.height - windowLength) & " when the height is " & $blockchain.height & ": " & e.msg)
    blockchain.difficulties.add(calculateNextDifficulty(
        blockchain.blockTime,
        windowLength,
        blockchain.difficulties,
        time
    ))
    blockchain.db.save(newBlock.header.hash, blockchain.difficulties[^1])
    if blockchain.difficulties.len > 72:
        blockchain.difficulties.delete(0)

    #Update the chain work.
    blockchain.chainWork += stuint(blockchain.difficulties[^1], 128)
    blockchain.db.save(newBlock.header.hash, blockchain.chainWork)

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

    #Load the reverted to difficulties.
    blockchain.difficulties = @[]
    var last: BlockHeader = blockchain.tail.header
    while blockchain.difficulties.len != 72:
        try:
            blockchain.difficulties = blockchain.db.loadDifficulty(last.hash) & blockchain.difficulties
        except DBReadError as e:
            panic("Couldn't load the difficulty of the Block we reverted to (or a Block before it): " & e.msg)

        if last.last == blockchain.genesis:
            break
        else:
            try:
                last = blockchain.db.loadBlockHeader(last.last)
            except DBReadError as e:
                panic("Couldn't load a BlockHeader for a Block we reverted to (or a Block before it): " & e.msg)

    #Load the chain work.
    blockchain.chainWork = blockchain.db.loadChainWork(blockchain.tail.header.hash)

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
