import lib/UInt

import Reputation/Block
import Reputation/Blockchain

var a, b: UInt
a = newUInt("8")
b = newUInt("6")
echo "2: " & $(a - b)

a = newUInt("10")
b = newUInt("8")
echo "2: " & $(a - b)

a = newUInt("1000")
b = newUInt("998")
echo "2: " & $(a - b)

a = newUInt("1001")
b = newUInt("999")
echo "2: " & $(a - b)

a = newUInt("1111")
b = newUInt("999")
echo "2: " & $(a - b)

a = newUInt("1111")
b = newUInt("1111")
echo "0: " & $(a - b)

discard """
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
"""
