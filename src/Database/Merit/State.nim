#BigNumber lib.
import BN as BNLib

#Block and Blockchain libs.
import Block
import Blockchain

#Tables standard lib.
import tables

#State object. It uses ref BN to prevent a compiler crash.
type State* = ref object of RootObj
    #Blocks until Merit is dead.
    deadBlocks: int
    #Live Merit.
    live*: int
    #Address -> Merit
    data: ref Table[string, ref BN]

#Constructor.
proc newState*(deadBlocks: int): State {.raises: [].} =
    State(
        deadBlocks: deadBlocks,
        live: 0,
        data: newTable[string, ref BN]()
    )

#Get the Merit of an account.
proc getBalance*(state: State, account: string): BN {.raises: [ValueError].} =
    #Set the result to 0 (in case there isn't an entry in the table).
    result = BNNums.Zero

    #If there is an entry, set the result to it.
    if state.data.hasKey(account):
        result = state.data[account][]

#Process a block.
proc processBlock*(state: State, blockchain: Blockchain, newBlock: Block) {.raises: [ValueError].} =
    #Grab the miners.
    var miners: seq[tuple[miner: string, amount: int]] = newBlock.miners

    #For each miner, add their Merit to the State.
    for miner in miners:
        state.data[miner.miner] = (state.getBalance(miner.miner) + newBN(miner.amount)).toRef()
        state.live += miner.amount

    #If the Blockchain's height is over 50k, meaning there is a block to remove from the state...
    if blockchain.height > newBN(state.deadBlocks):
        #Get the block that should be removed.
        miners = blockchain.blocks[^(state.deadBlocks + 1)].miners
        #For each miner, remove their Merit from the State.
        for miner in miners:
            state.data[miner.miner] = (state.getBalance(miner.miner) - newBN(miner.amount)).toRef()
            state.live -= miner.amount

#Process every block in a blockchain.
proc processBlockchain*(state: State, blockchain: Blockchain) {.raises: [ValueError].} =
    for i in blockchain.blocks:
        state.processBlock(blockchain, i)

#Constructor. It's at the bottom so we can call processBlockchain.
proc newState*(blockchain: Blockchain, deadBlocks: int): State {.raises: [ValueError].} =
    result = newState(deadBlocks)
    result.processBlockchain(blockchain)
