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

        state: newState(db, live)
    )
    result.epochs = newEpochs(db, verifications, result.blockchain)

#Add a block.
proc processBlock*(
    merit: Merit,
    verifications: Verifications,
    newBlock: Block
): Epoch {.raises: [
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

    #Have the Epochs process the Block and return the popped Epoch.
    result = merit.epochs.shift(
        verifications,
        newBlock.verifications
    )
