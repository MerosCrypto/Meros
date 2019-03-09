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
import ../../Network/Serialize/Merit/ParseBlock
import ../../Network/Serialize/Merit/ParseBlockHeader

#Finals lib.
import finals

#Merit master object for a blockchain and state.
type Merit* = ref object of RootObj
    blockchain*: Blockchain
    state*: State
    epochs: Epochs

#Constructor.
proc newMerit*(
    genesis: string,
    blockTime: uint,
    startDifficulty: string,
    live: uint,
    db: DatabaseFunctionBox
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
            genesis,
            blockTime,
            startDifficulty.toBN(16),
            db
        ),

        state: newState(live),

        epochs: newEpochs()
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

    #Regenerate the Difficulties.

    #Regenerate the State.

    #Regenerate the Epochs.

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
    var epoch: Epoch = merit.epochs.shift(verifications, newBlock.verifications)
    #Calculate the rewards.
    result = epoch.calculate(merit.state)
