#Number lib.
import ../../lib/BN

#Block/Blockchain/State libs.
import Merkle
import Block
import Blockchain
import State
#Export the Merkle and Block lib for miners.
export Merkle
export Block

#Merit master object for a blockchain and state.
type Merit* = ref object of RootObj
    blockchain: Blockchain
    state: State

#Creates A Merit object based on a Gensis string.
proc newMerit*(genesis: string): Merit {.raises: [ValueError, AssertionError].} =
    result = Merit(
        blockchain: newBlockchain(genesis),
        state: newState()
    )

#Add a block.
proc processBlock*(merit: Merit, newBlock: Block): bool {.raises: [AssertionError, Exception].} =
    result = true
    #Add the block to the Blockchain.
    if not merit.blockchain.addBlock(newBlock):
        #If that fails, return false.
        return false

    #Have the state process the block.
    merit.state.processBlock(newBlock)

#Getters.
proc getHeight*(merit: Merit): BN {.raises: [].} =
    merit.blockchain.getHeight()
proc getBlocks*(merit: Merit): seq[Block] {.raises: [].} =
    merit.blockchain.getBlocks()
proc getBalance*(merit: Merit, account: string): BN {.raises: [ValueError].} =
    merit.state.getBalance(account)
