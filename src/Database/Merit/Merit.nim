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
    var startDifficulty: Hash[256]
    try:
        startDifficulty = startDifficultyArg.toHash(256)
    except ValueError as e:
        panic("Invalid chain specs (start difficulty) passed to newMerit: " & e.msg)

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
) {.inline, forceCheck: [].} =
    merit.blockchain.processBlock(newBlock)

#Process a Block already addded to the Blockchain.
proc postProcessBlock*(
    merit: Merit
): (Epoch, uint16, int) {.forceCheck: [].} =
    #Have the Epochs process the Block and return the popped Epoch.
    result[0] = merit.epochs.shift(merit.blockchain.tail)

    #Have the state process the block.
    (result[1], result[2]) = merit.state.processBlock(merit.blockchain)
