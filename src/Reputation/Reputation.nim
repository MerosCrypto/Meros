import ../lib/BN

import Block as BlockFile
import Blockchain
import State

import lists

export BlockFile

type Reputation* = ref object of RootObj
    blockchain: Blockchain
    state: State

proc newReputation*(genesis: string): Reputation =
    result = Reputation(
        blockchain: newBlockchain(genesis),
        state: newState()
    )

proc testBlock*(reputation: Reputation, newBlock: Block): bool =
    result = true
    if not reputation.blockchain.testBlock(newBlock):
        result = false
        return

proc processBlock*(reputation: Reputation, newBlock: Block): bool =
    result = true
    if not reputation.blockchain.addBlock(newBlock):
        result = false
        return

    reputation.state.processBlock(newBlock)

proc getGenesis*(reputation: Reputation): string =
    result = reputation.blockchain.getGenesis()

proc getHeight*(reputation: Reputation): BN =
    result = reputation.blockchain.getHeight()

proc getBlocks*(reputation: Reputation): DoublyLinkedList[Block] =
    result = reputation.blockchain.getBlocks()

iterator getBlocks*(reputation: Reputation): Block =
    var blocks: DoublyLinkedList[Block] = reputation.getBlocks()
    for i in blocks.items():
        yield i

proc getBalance*(reputation: Reputation, account: string): BN =
    result = reputation.state.getBalance(account)
