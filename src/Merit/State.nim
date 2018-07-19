import BN as BNFile

import Block
import Blockchain

import tables

type State* = ref Table[string, BN]

proc newState*(): State {.raises: [].} =
    result = new State
    result[] = initTable[string, BN]()

proc getBalance*(state: State, account: string): BN {.raises: [KeyError].} =
    result = newBN("0")
    if state.hasKey(account):
        result = state[account]

proc processBlock*(state: State, newBlock: Block) {.raises: [KeyError].} =
    state[newBlock.getMiner()] = state.getBalance(newBlock.getMiner()) + newBN("100")

proc processBlockchain*(state: State, blockchain: Blockchain) {.raises: [KeyError].} =
    state[] = initTable[string, BN]()
    for i in blockchain.getBlocks():
        state.processBlock(i)

proc newState*(blockchain: Blockchain): State {.raises: [KeyError].} =
    result = new State
    result[] = initTable[string, BN]()
    result.processBlockchain(blockchain)
