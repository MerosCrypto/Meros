import ../lib/BN

import Block as BlockFile
import Blockchain
import State

import lists

export BlockFile

type Merit* = ref object of RootObj
    blockchain: Blockchain
    state: State

proc newMerit*(genesis: string): Merit {.raises: [ValueError, OverflowError, AssertionError, Exception].} =
    result = Merit(
        blockchain: newBlockchain(genesis),
        state: newState()
    )

proc testBlock*(merit: Merit, newBlock: Block): bool {.raises: [OverflowError, AssertionError, Exception].} =
    result = true
    if not merit.blockchain.testBlock(newBlock):
        result = false
        return

proc processBlock*(merit: Merit, newBlock: Block): bool {.raises: [OverflowError, AssertionError, Exception].} =
    result = true
    if not merit.blockchain.addBlock(newBlock):
        result = false
        return

    merit.state.processBlock(newBlock)

proc getGenesis*(merit: Merit): string {.raises: [].} =
    result = merit.blockchain.getGenesis()

proc getHeight*(merit: Merit): BN {.raises: [].} =
    result = merit.blockchain.getHeight()

proc getBlocks*(merit: Merit): DoublyLinkedList[Block] {.raises: [].} =
    result = merit.blockchain.getBlocks()

iterator getBlocks*(merit: Merit): Block {.raises: [].} =
    var blocks: DoublyLinkedList[Block] = merit.getBlocks()
    for i in blocks.items():
        yield i

proc getBalance*(merit: Merit, account: string): BN {.raises: [KeyError].} =
    result = merit.state.getBalance(account)
