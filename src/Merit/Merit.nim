#Number lib.
import BN

#Block/Blockchain/State libs.
import Block as BlockFile
import Blockchain
import State
#Export the Block lib for miners.
export BlockFile

#Lists standard lib.
import lists

#Merit master object for a blockchain and state.
type Merit* = ref object of RootObj
    blockchain: Blockchain
    state: State

#Creates A Merit object based on a Gensis string.
proc newMerit*(genesis: string): Merit {.raises: [ValueError, OverflowError, AssertionError, Exception].} =
    result = Merit(
        blockchain: newBlockchain(genesis),
        state: newState()
    )

#Tests a block.
proc testBlock*(merit: Merit, newBlock: Block): bool {.raises: [OverflowError, AssertionError, Exception].} =
    result = true
    #If the blockchain rejects the block...
    if not merit.blockchain.testBlock(newBlock):
        result = false
        return

#Add a block.
proc processBlock*(merit: Merit, newBlock: Block): bool {.raises: [OverflowError, AssertionError, Exception].} =
    result = true
    #Add the block to the Blockchain.
    if not merit.blockchain.addBlock(newBlock):
        #If that fails, return false.
        result = false
        return

    #Have the state process the block.
    merit.state.processBlock(newBlock)

#Getters for:
#The genesis string.
#The blockchain height.
#Blocks (and an iterator for them).
#An address's balance.
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
