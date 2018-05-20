import lib/time

import Reputation/Block
import Reputation/Blockchain

var
    blockchain: Blockchain = createBlockchain("0")
    newBlock: Block

var nonce: uint32 = (uint32) 1

newBlock = createBlock(nonce, "1", "a")
addBlock(blockchain, newBlock)
inc(nonce)

newBlock = createBlock(nonce, "1", "b")
blockchain.addBlock(newBlock)
inc(nonce)

newBlock = createBlock(nonce, "1", "b")
blockchain.addBlock(newBlock)
inc(nonce)

newBlock = createBlock(nonce, "1", "d")
blockchain.addBlock(newBlock)
inc(nonce)

newBlock = createBlock(nonce, "1", "d")
blockchain.addBlock(newBlock)
inc(nonce)

newBlock = createBlock(6, getTime() + 310, "1", "d")
blockchain.addBlock(newBlock)
