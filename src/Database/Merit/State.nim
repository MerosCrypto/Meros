#Errors lib.
import ../../lib/Errors

#MinerWallet lib (for BLSPublicKey's toString).
import ../../Wallet/MinerWallet

#DB Function Box object.
import ../../objects/GlobalFunctionBoxObj

#Miners object.
import objects/MinersObj

#Block and Blockchain libs.
import Block
import Blockchain

#State object.
import objects/StateObj
export StateObj

#Constructor.
proc newState*(
    db: DatabaseFunctionBox,
    deadBlocks: Natural
): State {.forceCheck: [].} =
    newStateObj(db, deadBlocks)

#Process a block.
proc processBlock*(
    state: var State,
    blockchain: Blockchain,
    newBlock: Block
) {.forceCheck: [].} =
    #Grab the miners.
    var miners: seq[Miner] = newBlock.miners.miners

    #For each miner, add their Merit to the State.
    for miner in miners:
        state[miner.miner] = state[miner.miner] + miner.amount

    #If the Blockchain's height is over the dead blocks quantity, meaning there is a block to remove from the state...
    if blockchain.height > state.deadBlocks:
        #For each miner, remove their Merit from the State.
        try:
            for miner in blockchain[blockchain.height - (state.deadBlocks + 1)].miners.miners:
                state[miner.miner] = state[miner.miner] - miner.amount
        except IndexError as e:
            doAssert(false, "State tried to remove dead Merit yet couldn't get the old Block: " & e.msg)

    #Save the State to the DB.
    state.save()
