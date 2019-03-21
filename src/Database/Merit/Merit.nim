#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Base lib.
import ../../lib/Base

#BLS lib.
import ../../lib/BLS

#Verifications lib.
import ../Verifications/Verifications

#DB Function Box object.
import ../../objects/GlobalFunctionBoxObj

#VerifierIndex object.
import objects/VerifierIndexObj
export VerifierIndexObj

#Miners object.
import objects/MinersObj
export MinersObj

#Every Merit lib.
import Difficulty
import Block
import Blockchain
import State
import Epochs

export Difficulty
export Block
export Blockchain
export State
export Epochs

#Serialize libs.
import ../../Network/Serialize/SerializeCommon
import ../../Network/Serialize/Merit/SerializeBlock
import ../../Network/Serialize/Merit/ParseBlockHeader
import ../../Network/Serialize/Merit/ParseBlock
import ../../Network/Serialize/Merit/SerializeDifficulty
import ../../Network/Serialize/Merit/ParseDifficulty

#Tables standard lib.
import tables

#Finals lib.
import finals

#Merit master object for a blockchain and state.
type Merit* = ref object of RootObj
    blockchain*: Blockchain
    state*: State
    epochs: Epochs

#Constructor.
proc newMerit*(
    db: DatabaseFunctionBox,
    verifications: Verifications,
    genesis: string,
    blockTime: uint,
    startDifficulty: string,
    live: uint
): Merit {.raises: [
    ValueError,
    ArgonError,
    BLSError,
    LMDBError,
    FinalAttributeError
].} =
    #Create the Merit object.
    result = Merit(
        blockchain: newBlockchain(
            db,
            genesis,
            blockTime,
            startDifficulty.toBN(16)
        ),

        state: newState(db, live),

        epochs: newEpochs(db)
    )

    #Grab the tip.
    var tip: string = ""
    try:
        tip = db.get("merit_tip")
    except:
        #If the tip isn't defined, set the tip to the genesis block.
        var genesisBlock: Block = newBlockObj(
            0,
            genesis.pad(64).toArgonHash(),
            nil,
            @[],
            @[],
            0,
            0
        )
        tip = genesisBlock.header.hash.toString()
        db.put("merit_tip", tip)
        db.put("merit_" & tip, genesisBlock.serialize())

        #Also set the Difficulty to the starting difficulty.
        db.put("merit_difficulty", result.blockchain.difficulty.serialize())

    #Load every header.
    var
        headers: seq[BlockHeader]
        last: BlockHeader = parseBlockHeader(db.get("merit_" & tip).deserialize(3)[0])
        i: int = 0
    headers = newSeq[BlockHeader](last.nonce + 1)

    while last.nonce != 0:
        last = parseBlockHeader(db.get("merit_" & last.last.toString()).deserialize(3)[0])
        headers[i] = last
        inc(i)
    headers[i] = last

    result.blockchain.setHeight(uint(headers.len))
    for header in headers:
        result.blockchain.load(header)

    #Load the blocks we want to cache.
    if headers.len < 12:
        for h in countdown(headers.len - 1, 0):
            result.blockchain.load(parseBlock(db.get("merit_" & headers[h].hash.toString())))
    else:
        for h in countdown(headers.len - 1, headers.len - 12):
            result.blockchain.load(parseBlock(db.get("merit_" & headers[h].hash.toString())))

    #Load the Difficulty.
    result.blockchain.load(parseDifficulty(db.get("merit_difficulty")))

    #Regenerate the Epochs.

    var
        #Table of every archived tip before the current Epochs.
        tips: TableRef[string, uint] = newTable[string, uint]()
        #Table of every archived tip before the 6 Epochs before the current Epochs.
        prevtips: TableRef[string, uint] = newTable[string, uint]()
        #Table of every Entry mentioned in the 6 Epochs before the Epochs we're mentioning.
        ignore: TableRef[string, bool] = newTable[string, bool]()
    #Use the Holders string from the State.
    if result.state.holdersStr != "":
        for i in countup(0, result.state.holdersStr.len, 48):
            #Extract the holder.
            var holder = result.state.holdersStr[i .. i + 47]

            #Load their tip.
            try:
                tips[holder] = uint(db.get("merit_" & holder & "_epoch").fromBinary())
            except:
                #If this failed, it's because they have Merit but don't have Verifications older than 6 blocks.
                continue

            #Load their previous tip.
            try:
                prevtips[holder] = uint(db.get("merit_" & holder & "_previous_epoch").fromBinary())
            except:
                #If this failed, it's because they have Merit but don't have Verifications older then 12 blocks.
                continue

            #Grab every hash that's mentioned in the six blocks before the six Epochs we regenerate.
            for i in prevtips[holder] .. tips[holder]:
                ignore[verifications[holder][i].hash.toString()] = true

    for i in 1 .. 6:
        result.epochs.shift(
            verifications,
            result.blockchain[result.blockchain.height - uint(i)].verifications,
            tips,
            ignore
        )

#Add a block.
proc processBlock*(
    merit: Merit,
    verifications: Verifications,
    newBlock: Block
): Rewards {.raises: [
    KeyError,
    ValueError,
    ArgonError,
    BLSError,
    LMDBError,
    FinalAttributeError
].} =
    #Add the block to the Blockchain.
    if not merit.blockchain.processBlock(newBlock):
        #If that fails, throw a ValueError.
        raise newException(ValueError, "Invalid Block.")

    #Have the state process the block.
    merit.state.processBlock(merit.blockchain, newBlock)

    #Have the Epochs process the Block.
    var epoch: Epoch = merit.epochs.shift(
        verifications,
        newBlock.verifications
    )
    #Calculate the rewards.
    result = epoch.calculate(merit.state)
