#Errors lib.
import ../../lib/Errors

#Hash lib. Used for printing hashes in error messages.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Merit DB lib.
import ../Filesystem/DB/MeritDB

#MeritRemoval object.
import ../Consensus/Elements/objects/MeritRemovalObj

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

#Get the nickname of the miner in a Block.
proc getNickname(
    state: var State,
    blockArg: Block,
    newBlock: bool = false
): uint16 {.forceCheck: [].} =
    if blockArg.header.newMiner:
        try:
            result = state.reverseLookup(blockArg.header.minerKey)
        except IndexError:
            if newBlock:
                return state.newHolder(blockArg.header.minerKey)
            doAssert(false, $blockArg.header.minerKey & " in Block " & $blockArg.header.hash & " doesn't have a nickname.")
    else:
        result = blockArg.header.minerNick

#Process a block.
proc processBlock*(
    state: var State,
    blockchain: Blockchain,
    newBlock: Block
) {.forceCheck: [].} =
    #Save the amount of live Merit.
    state.saveLive()

    #Add the miner's Merit to the State.
    var nick: uint16 = state.getNickname(newBlock, true)
    state[nick] = state[nick] + 1

    #If the Blockchain's height is over the dead blocks quantity, meaning there is a block to remove from the state...
    if blockchain.height > state.deadBlocks + 1:
        #Remove the miner's Merit from the State.
        try:
            nick = state.getNickname(blockchain[blockchain.height - 1 - state.deadBlocks])
        except IndexError as e:
            doAssert(false, "State tried to remove dead Merit yet couldn't get the old Block: " & e.msg)

        #Do nothing if they had their Merit removed.
        var
            removals: seq[int] = state.loadHolderRemovals(nick)
            removed: bool = false
        for removal in removals:
            if removal >= blockchain.height - 1 - state.deadBlocks:
                removed = true
                break

        #If they didn't have their Merit removed, remove their old Merit.
        if not removed:
            state[nick] = state[nick] - 1

    #Remove Merit from Merit Holders who had their Merit Removals archived in this Block.
    for elem in newBlock.body.elements:
        if elem of MeritRemoval:
            state.remove(elem.holder, blockchain.height - 1)

    #Increment the amount of processed Blocks.
    inc(state.processedBlocks)

    #Save the amount of live Merit for the next Block.
    #This will be overwritten when we process the next Block, yet is needed for some statuses.
    state.saveLive()

#Calculate the Verification threshold for an Epoch that ends on the specified Block.
proc protocolThresholdAt*(
    state: State,
    blockNum: int
): int {.inline, forceCheck: [].} =
    state.loadLive(blockNum) div 2 + 1

#Calculate the threshold for an Epoch that ends on the specified Block.
proc nodeThresholdAt*(
    state: State,
    blockNum: int
): int {.inline, forceCheck: [].} =
    state.loadLive(blockNum) div 100 * 80

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
            #Nickname of the miner we're handling.
            nick: uint16
            #Block we're reverting past.
            revertingPast: Block
        try:
            revertingPast = blockchain[i]
        except IndexError as e:
            doAssert(false, "Couldn't get the Block to revert past: " & e.msg)

        #Restore removed Merit.
        for removal in state.loadBlockRemovals(i):
            state[removal.nick] = removal.merit

        #Grab the miner's nickname.
        nick = state.getNickname(revertingPast)

        #Remove the Merit rewarded by the Block we just reverted past.
        state[nick] = state[nick] - 1

        #If the miner was new to this Block, remove their nickname.
        if revertingPast.header.newMiner:
            state.deleteLastNickname()

        #If i is over the dead blocks quantity, meaning there is a historical Block to add back to the State...
        if i > state.deadBlocks:
            #Get the miner for said historical Block.
            try:
                nick = state.getNickname(blockchain[i - state.deadBlocks])
            except IndexError as e:
                doAssert(false, "State couldn't get a historical Block being revived into the State: " & e.msg)

            #Don't add Merit if the miner had a MeritRemoval.
            var removed: bool = false
            for removal in state.loadHolderRemovals(nick):
                if (removal >= i - state.deadBlocks) and (removal < height):
                    removed = true
                    break

            #Add back the Merit which died.
            if not removed:
                state[nick] = state[nick] + 1

        #Increment the amount of processed Blocks.
        dec(state.processedBlocks)

    state.oldData = false
