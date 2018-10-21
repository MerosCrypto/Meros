#Errors lib.
import ../../lib/Errors

#Base lib.
import ../../lib/Base

#Miners object, Verification/Block/Blockchain/State, and MinerWallet libs.
import objects/MinersObj
import Verifications
import Block
import Blockchain
import State
import Miner/MinerWallet

export MinersObj
export Verifications
export Block
export Blockchain
export State
export MinerWallet

#Merit master object for a blockchain and state.
type Merit* = ref object of RootObj
    blockchain*: Blockchain
    state*: State

#Constructor.
proc newMerit*(
    genesis: string,
    blockTime: uint,
    startDifficulty: string,
    live: uint
): Merit {.raises: [ValueError, ArgonError].} =
    result = Merit(
        blockchain: newBlockchain(genesis, blockTime, startDifficulty.toBN(16)),
        state: newState(live)
    )

#Add a block.
proc processBlock*(
    merit: Merit,
    newBlock: Block
): bool {.raises: [
    KeyError,
    ValueError,
    BLSError,
    SodiumError
].} =
    result = true

    #Add the block to the Blockchain.
    if not merit.blockchain.processBlock(newBlock):
        #If that fails, return false.
        return false

    #Have the state process the block.
    merit.state.processBlock(merit.blockchain, newBlock)
