#Errors lib.
import ../../lib/Errors

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
import ../../Network/Serialize/Merit/SerializeBlock

#Finals lib.
import finals

#Merit master object for a blockchain and state.
type Merit* = ref object of RootObj
    db: DatabaseFunctionBox

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
): Merit {.raises: [ValueError, ArgonError].} =
    result = Merit(
        db: db,

        blockchain: newBlockchain(
            genesis,
            blockTime,
            startDifficulty.toBN(16),
            db
        ),

        state: newState(live),

        epochs: newEpochs()
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
    var epoch: Epoch = merit.epochs.shift(verifications, newBlock.verifications)
    #Calculate the rewards.
    result = epoch.calculate(merit.state)

    #Save the block to the database.
    merit.db.put("merit_" & newBlock.header.hash.toString(), newBlock.serialize())
    merit.db.put("merit_tip", newBlock.header.hash.toString())
