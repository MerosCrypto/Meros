#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#BLS lib.
import ../../lib/BLS

#DB Function Box object.
import ../../objects/GlobalFunctionBoxObj

#Miners object.
import objects/MinersObj

#Block and Blockchain libs.
import Block
import Blockchain

#State object.
import objects/StateObj
#Export it.
export StateObj

#Finals lib.
import finals

#Process a block.
proc processBlock*(
    state: State,
    blockchain: Blockchain,
    newBlock: Block
) {.raises: [
    KeyError,
    ValueError,
    ArgonError,
    BLSError,
    LMDBError,
    FinalAttributeError
].} =
    #Grab the miners.
    var miners: Miners = newBlock.miners

    #For each miner, add their Merit to the State.
    for miner in miners:
        state[miner.miner.toString()] = state[miner.miner] + miner.amount

    #If the Blockchain's height is over the dead blocks quantity, meaning there is a block to remove from the state...
    if blockchain.height > state.deadBlocks:
        #Get the block that should be removed.
        miners = blockchain[blockchain.height - (state.deadBlocks + 1)].miners
        #For each miner, remove their Merit from the State.
        for miner in miners:
            state[miner.miner.toString()] = state[miner.miner] - miner.amount
