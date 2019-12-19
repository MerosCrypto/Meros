#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Merit DB lib.
import ../Filesystem/DB/MeritDB

#Merit libs.
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

#Blockchain, State, and Epochs wrapper.
type Merit* = ref object
    blockchain*: Blockchain
    state*: State
    epochs*: Epochs

#Constructor.
proc newMerit*(
    db: DB,
    genesis: string,
    blockTime: int,
    startDifficultyArg: string,
    deadBlocks: int
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
        )
    )
    result.state = newState(db, deadBlocks, result.blockchain.height)
    result.epochs = newEpochs(result.blockchain)

#Add a Block to the Blockchain.
proc processBlock*(
    merit: Merit,
    newBlock: Block
) {.forceCheck: [
    ValueError
].} =
    try:
        merit.blockchain.processBlock(newBlock)
    except ValueError as e:
        raise e

#Process a Block already addded to the Blockchain.
proc postProcessBlock*(
    merit: Merit
): Epoch {.forceCheck: [].} =
    #Have the Epochs process the Block and return the popped Epoch.
    result = merit.epochs.shift(merit.blockchain.tail)

    #Have the state process the block.
    merit.state.processBlock(merit.blockchain)
