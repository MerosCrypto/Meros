import BN as BNLib

import ../../lib/Merkle

import Block
import Blockchain

import SetOnce

import math
import tables

type State* = ref Table[string, ref BN]

proc newState*(): State {.raises: [].} =
    result = newTable[string, ref BN]()

proc getBalance*(state: State, account: string): BN {.raises: [ValueError].} =
    result = newBN()
    if state.hasKey(account):
        result = state[account][]

proc processBlock*(state: State, newBlock: Block, blockchain: Blockchain) {.raises: [ValueError].} =

    let
        disgardMeritMiners: seq[tuple[miner: string, amount: int]] = blockchain.blocks[^50].miners
        miners: seq[tuple[miner: string, amount: int]] = newBlock.miners

    for miner in miners:
        state[miner.miner] = (state.getBalance(miner.miner) + newBN(miner.amount)).toRef()

    for miner in disgardMeritMiners:
        state[miner.miner] = (state.getBalance(miner.miner) - newBN(miner.amount)).toRef()

proc processBlockchain*(state: State, blockchain: Blockchain) {.raises: [ValueError].} =
    for i in blockchain.blocks:
        state.processBlock(i, blockchain)


proc newState*(blockchain: Blockchain): State {.raises: [ValueError].} =
    result = newState()
    result.processBlockchain(blockchain)
