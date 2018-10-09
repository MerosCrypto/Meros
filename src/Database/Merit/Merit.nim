#Errors lib.
import ../../lib/Errors

#Numerical libs.
import BN
import ../../lib/Base

#Merkle lib.
import ../../lib/Merkle
export Merkle

#Miners object and the Verification/Block/Blockchain/State libs.
import objects/MinersObj
import Verification
import Block
import Blockchain
import State

export MinersObj
export Verification
export Block
export Blockchain
export State

#Merit master object for a blockchain and state.
type Merit* = ref object of RootObj
    blockchain*: Blockchain
    state*: State

#Constructor.
proc newMerit*(
    genesis: string,
    blockTime: int,
    startDifficulty: string,
    live: int
): Merit {.raises: [ValueError, ArgonError].} =
    result = Merit(
        blockchain: newBlockchain(genesis, blockTime, startDifficulty.toBN(16)),
        state: newState(live)
    )

#Add a block.
proc processBlock*(merit: Merit, newBlock: Block): bool {.raises: [KeyError, ValueError].} =
    result = true

    #Add the block to the Blockchain.
    if not merit.blockchain.addBlock(newBlock):
        #If that fails, return false.
        return false

    #Have the state process the block.
    merit.state.processBlock(merit.blockchain, newBlock)
