#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Base lib.
import ../../lib/Base

#BLS lib.
import ../../lib/BLS

#Miners object.
import objects/MinersObj
export MinersObj

#Every Merit lib.
import Difficulty
import Verifications
import Block
import Blockchain
import State
import Epochs
import MinerWallet

export Difficulty
export Verifications
export Block
export Blockchain
export State
export Epochs
export MinerWallet

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
    live: uint
): Merit {.raises: [ValueError, ArgonError].} =
    Merit(
        blockchain: newBlockchain(genesis, blockTime, startDifficulty.toBN(16)),
        state: newState(live),
        epochs: newEpochs()
    )

#Add a block.
proc processBlock*(
    merit: Merit,
    newBlock: Block
): Rewards {.raises: [
    KeyError,
    ValueError,
    BLSError,
    SodiumError,
    FinalAttributeError
].} =
    #Add the block to the Blockchain.
    if not merit.blockchain.processBlock(newBlock):
        #If that fails, throw a ValueError.
        raise newException(ValueError, "Invalid Block.")

    #Have the state process the block.
    merit.state.processBlock(merit.blockchain, newBlock)

    #Have the Epochs process the Block.
    var epoch: Epoch = merit.epochs.shift(newBlock.verifications)
    #Calculate the rewards.
    result = epoch.calculate(merit.state)
