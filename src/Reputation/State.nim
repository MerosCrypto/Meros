import ../lib/BN as BNFile

import Block
import Blockchain

import tables

type State* = ref object of RootObj
    state: Table[string, BN]

proc getBalance*(state: State, account: string): BN =
    result = newBN("0")
    if state.state.hasKey(account):
        result = state.state[account]

proc createState*(): State =
    result = State(
        state: initTable[string, BN]()
    )

proc processBlock*(state: State, newBlock: Block) =
    state.state[newBlock.getMiner()] = state.getBalance(newBlock.getMiner()) + newBN("100")

proc processBlockchain*(state: State, blockchain: Blockchain) =
    state.state = initTable[string, BN]()
    for i in blockchain.getBlocks():
        state.processBlock(i)

proc createState*(blockchain: Blockchain): State =
    result = State(
        state: initTable[string, BN]()
    )

    result.processBlockchain(blockchain)
