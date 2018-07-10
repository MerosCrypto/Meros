import ../lib/BN as BNFile

import Block
import Blockchain

import tables

type State* = ref Table[string, BN]

proc newState*(): State =
    result = new State
    result[] = initTable[string, BN]()

proc getBalance*(state: State, account: string): BN =
    result = newBN("0")
    if state.hasKey(account):
        result = state[account]

proc processBlock*(state: State, newBlock: Block) =
    state[newBlock.getMiner()] = state.getBalance(newBlock.getMiner()) + newBN("100")

proc processBlockchain*(state: State, blockchain: Blockchain) =
    state[] = initTable[string, BN]()
    for i in blockchain.getBlocks():
        state.processBlock(i)

proc newState*(blockchain: Blockchain): State =
    result = new State
    result[] = initTable[string, BN]()
    result.processBlockchain(blockchain)
