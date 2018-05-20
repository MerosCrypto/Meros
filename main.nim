import lib/UInt
import lib/Hex

import Reputation/Block
import Reputation/Blockchain

import os

var
    blockchain: Blockchain = createBlockchain("0")
    newBlock: Block
    nonce: UInt = newUInt("1")
    proof: UInt = newUInt("0")

echo "Entering while loop"
while true:
    sleep(1000)
    echo "Looping..."
    try:
        newBlock = createBlock(nonce, "1", Hex.convert(proof))
        addBlock(blockchain, newBlock)
    except:
        inc(proof)
        continue
    echo "Mined a block: " & $nonce
    inc(nonce)
    proof = newUInt("0")
