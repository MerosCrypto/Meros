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
    deadBlocks: int,
    blockchainHeight: int,
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
                #Skip miners who had their Merit killed by a MeritRemoval.
                var
                    removals: seq[int] = state.loadRemovals(miner.miner)
                    removed: bool = false
                for removal in removals:
                    if removal >= newBlock.nonce - state.deadBlocks:
                        removed = true
                        break
                if removed:
                    continue

                state[miner.miner] = state[miner.miner] - miner.amount
        except IndexError as e:
            doAssert(false, "State tried to remove dead Merit yet couldn't get the old Block: " & e.msg)

    #Increment the amount of processed Blocks.
    inc(state.processedBlocks)

#Remove a MeritHolder's Merit.
proc remove*(
    state: var State,
    key: BLSPublicKey,
    archiving: Block
) {.forceCheck: [].} =
    state.removeInternal(key, archiving)

#Revert to a certain block height.
proc revert*(
    state: var State,
    blockchain: Blockchain,
    height: int
) {.forceCheck: [].} =
    #Mark the State as working with old data.
    state.oldData = true

    for i in countdown(state.processedBlocks - 1, height):
        var
            #Holder's MeritRemovals.
            holderRemovals: seq[int]
            #Block's MeritRemovals.
            blockRemovals: seq[tuple[key: BLSPublicKey, merit: int]]
            #Removed.
            removed: bool

        #Grab the miners.
        var miners: seq[Miner]
        try:
            miners = blockchain[i].miners.miners
        except IndexError as e:
            doAssert(false, "Told to revert to a height higher than we have: " & e.msg)

        #Restore removed Merit.
        blockRemovals = state.loadRemovals(i)
        for removal in blockRemovals:
            state[removal.key] = removal.merit

        #For each miner, remove their Merit from the State.
        for miner in miners:
            state[miner.miner] = state[miner.miner] - miner.amount

        #If i is over the dead blocks quantity, meaning there is a Block to remove from the State...
        if i > state.deadBlocks:
            #For each miner, add their Merit back to the State.
            try:
                for miner in blockchain[i - state.deadBlocks].miners.miners:
                    #Skip miners who had this Merit killed by a MeritRemoval.
                    holderRemovals = state.loadRemovals(miner.miner)
                    removed = false
                    for removal in holderRemovals:
                        if (removal >= i - state.deadBlocks) and (removal < height):
                            removed = true
                            break
                    if removed:
                        continue

                    state[miner.miner] = state[miner.miner] + miner.amount
            except IndexError as e:
                doAssert(false, "State tried to add back dead Merit yet couldn't get the old Block: " & e.msg)

        #Increment the amount of processed Blocks.
        dec(state.processedBlocks)

    state.oldData = false
