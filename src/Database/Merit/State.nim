#Errors lib.
import ../../lib/Errors

#MinerWallet lib (for BLSPublicKey's toString).
import ../../Wallet/MinerWallet

#Merit DB lib.
import ../Filesystem/DB/MeritDB

#Miners object.
import objects/MinersObj

#BlockHeader, Block, and Blockchain libs.
import BlockHeader
import Block
import Blockchain

#State object.
import objects/StateObj
export StateObj

#Constructor.
proc newState*(
    db: DB,
    deadBlocks: Natural,
    blockchainHeight: Natural,
): State {.forceCheck: [].} =
    newStateObj(db, deadBlocks, blockchainHeight)

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
    if (newBlock.nonce + 1) > state.deadBlocks:
        #For each miner, remove their Merit from the State.
        try:
            for miner in blockchain[newBlock.nonce - state.deadBlocks].miners.miners:
                state[miner.miner] = state[miner.miner] - miner.amount
        except IndexError as e:
            doAssert(false, "State tried to remove dead Merit yet couldn't get the old Block: " & e.msg)

    #Increment the amount of processed Blocks.
    inc(state.processedBlocks)

#Revert to a certain block height.
proc revert*(
    state: var State,
    blockchain: Blockchain,
    height: int
) {.forceCheck: [].} =
    #Restore dead Merit first so we stay in the `Natural` range.
    for i in countdown(state.processedBlocks - 1, height):
        #If the i is over the dead blocks quantity, meaning there is a block to remove from the state...
        if i > state.deadBlocks:
            #For each miner, add their Merit back to the State.
            try:
                for miner in blockchain[i - state.deadBlocks].miners.miners:
                    state[miner.miner] = state[miner.miner] + miner.amount
            except IndexError as e:
                doAssert(false, "State tried to add back dead Merit yet couldn't get the old Block: " & e.msg)

        #Grab the miners.
        var miners: seq[Miner]
        try:
            miners = blockchain[i].miners.miners
        except IndexError as e:
            doAssert(false, "Told to revert to a height higher than we have: " & e.msg)

        #For each miner, remove their Merit from the State.
        for miner in miners:
            state[miner.miner] = state[miner.miner] - miner.amount

        #Increment the amount of processed Blocks.
        dec(state.processedBlocks)

proc catchup*(
    state: var State,
    blockchain: Blockchain
) {.forceCheck: [].} =
    if state.processedBlocks > blockchain.height:
        doAssert(false, "Trying to catch up to a chain which is shorter than the amount of Blocks processed by the State already.")

    for i in state.processedBlocks ..< blockchain.height:
        try:
            state.processBlock(blockchain, blockchain[i])
        except IndexError as e:
            doAssert(false, "Tried to catch up to a Blockchain yet failed to get a Block: " & e.msg)
