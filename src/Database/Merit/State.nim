#Miners object.
import objects/MinersObj

#Block and Blockchain libs.
import Block
import Blockchain

#Tables standard lib.
import tables

#Finals lib.
import finals

#State object.
finalsd:
    type State* = ref object of RootObj
        #Blocks until Merit is dead.
        deadBlocks* {.final.}: int
        #Live Merit.
        live*: uint
        #Address -> Merit
        data {.final.}: ref Table[string, uint]

#Constructor.
func newState*(deadBlocks: int): State {.raises: [].} =
    State(
        deadBlocks: deadBlocks,
        live: 0,
        data: newTable[string, uint]()
    )

#Get the Merit of an account.
func getBalance*(state: State, account: string): uint {.raises: [KeyError].} =
    #Set the result to 0 (in case there isn't an entry in the table).
    result = 0

    #If there is an entry, set the result to it.
    if state.data.hasKey(account):
        result = state.data[account]

#Process a block.
func processBlock*(
    state: State,
    blockchain: Blockchain,
    newBlock: Block
) {.raises: [KeyError].} =
    #Grab the miners.
    var miners: Miners = newBlock.miners

    #For each miner, add their Merit to the State.
    for miner in miners:
        state.data[miner.miner] = state.getBalance(miner.miner) + miner.amount
        state.live += miner.amount

    #If the Blockchain's height is over 50k, meaning there is a block to remove from the state...
    if blockchain.height > state.deadBlocks:
        #Get the block that should be removed.
        miners = blockchain.blocks[^(state.deadBlocks + 1)].miners
        #For each miner, remove their Merit from the State.
        for miner in miners:
            state.data[miner.miner] = state.getBalance(miner.miner) - miner.amount
            state.live -= miner.amount

#Process every block in a blockchain.
func processBlockchain*(
    state: State,
    blockchain: Blockchain
) {.raises: [KeyError].} =
    for i in blockchain.blocks:
        state.processBlock(blockchain, i)

#Constructor. It's at the bottom so we can call processBlockchain.
func newState*(
    blockchain: Blockchain,
    deadBlocks: int
): State {.raises: [KeyError].} =
    result = newState(deadBlocks)
    result.processBlockchain(blockchain)
