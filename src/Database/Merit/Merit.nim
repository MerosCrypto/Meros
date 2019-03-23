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

    #Regenerate the Epochs.
    #Table of every archived tip before the current Epochs.
    var tips: TableRef[string, int] = newTable[string, int]()
    #Use the Holders string from the State.
    if result.state.holdersStr != "":
        for i in countup(0, result.state.holdersStr.len - 1, 48):
            #Extract the holder.
            var holder = result.state.holdersStr[i .. i + 47]

            #Load their tip.
            try:
                tips[holder] = db.get("merit_" & holder & "_epoch").fromBinary()
            except:
                #If this failed, it's because they have Merit but don't have Verifications older than 6 blocks.
                tips[holder] = 0

    #Shift the last 12 blocks. Why?
    #We want to regenerate the Epochs for the last 6, but we need to regenerate the 6 before that so late verifications aren't labelled as first appearances.
    var start: int = 12
    #If the blockchain is smaller than 12, load every block.
    if result.blockchain.height < 12:
        start = int(result.blockchain.height)

    for i in countdown(start, 1):
        discard result.epochs.shift(
            verifications,
            result.blockchain[result.blockchain.height - uint(i)].verifications,
            tips
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
