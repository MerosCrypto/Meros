import lib/Hex

import Reputation/Block
import Reputation/Blockchain

import os

discard """
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
"""

var
    blockchain: Blockchain = createBlockchain("0")
    newBlock: Block
    nonce: uint32 = (uint32) 1
    proof: uint32 = (uint32) 0

while true:
    sleep(1000)
    try:
        newBlock = createBlock(nonce, "1", Hex.convert(proof))
        addBlock(blockchain, newBlock)
    except:
        inc(proof)
        continue
    echo "Mined a block: " & $nonce
    inc(nonce)
    proof = (uint32) 0
