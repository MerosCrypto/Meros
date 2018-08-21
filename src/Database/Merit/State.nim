import ../../lib/BN as BNFile

import Block
import Blockchain

import math
import tables

type State* = ref Table[string, BN]

proc newState*(): State {.raises: [].} =
    result = newTable[string, BN]()

proc getBalance*(state: State, account: string): BN {.raises: [ValueError].} =
    result = newBN()
    if state.hasKey(account):
        result = state[account]

proc processBlock*(state: State, newBlock: Block) {.raises: [ValueError].} =
    let miners: seq[tuple[miner: string, amount: int]] = newBlock.getMiners()

    for miner in miners:
        state[miner.miner] = state.getBalance(miner.miner) + newBN(miner.amount)

proc processBlockchain*(state: State, blockchain: Blockchain) {.raises: [ValueError].} =
    state[] = initTable[string, BN]()
    for i in blockchain.getBlocks():
        state.processBlock(i)

proc newState*(blockchain: Blockchain): State {.raises: [ValueError].} =
    result = newState()
    result.processBlockchain(blockchain)
