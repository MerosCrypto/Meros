#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Verifications lib.
import ../Verifications/Verifications

#DB Function Box object.
import ../../objects/GlobalFunctionBoxObj

#VerifierRecord object.
import ../common/objects/VerifierRecordObj
export VerifierRecordObj

#Miners object.
import objects/MinersObj
export MinersObj

#Every Merit lib.
import Difficulty
import BlockHeader
import Block
import Blockchain
import State
import Epochs

export Difficulty
export BlockHeader
export Block
export Blockchain
export State
export Epochs

#Merit master object for a blockchain and state.
type Merit* = ref object
    blockchain*: Blockchain
    state*: State
    epochs: Epochs

#Constructor.
proc newMerit*(
    db: DatabaseFunctionBox,
    verifications: Verifications,
    genesis: string,
    blockTime: Natural,
    startDifficultyArg: string,
    live: Natural
): Merit {.forceCheck: [].} =
    #Extract the Difficulty.
    var startDifficulty: Hash[384]
    try:
        startDifficulty = startDifficultyArg.toHash(384)
    except ValueError as e:
        doAssert(false, "Invalid chain specs (start difficulty) passed to newMerit: " & e.msg)

    #Create the Merit object.
    result = Merit(
        blockchain: newBlockchain(
            db,
            genesis,
            blockTime,
            startDifficulty
        ),

        state: newState(db, live)
    )
    result.epochs = newEpochs(db, verifications, result.blockchain)

#Add a block.
proc processBlock*(
    merit: Merit,
    verifications: Verifications,
    newBlock: Block
): Epoch {.forceCheck: [
    ValueError,
    GapError,
    DataExists
].} =
    #Add the block to the Blockchain.
    try:
        merit.blockchain.processBlock(newBlock)
    except ValueError as e:
        fcRaise e
    except GapError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e

    #Have the state process the block.
    merit.state.processBlock(merit.blockchain, newBlock)

    #Have the Epochs process the Block and return the popped Epoch.
    result = merit.epochs.shift(
        verifications,
        newBlock.records
    )
