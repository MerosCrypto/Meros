import lib/BN
import lib/Hex

import Reputation/Block
import Reputation/Blockchain

import os

var
    blockchain: Blockchain = createBlockchain("0")
    newBlock: Block
    nonce: BN = newBN("1")
    proof: BN = newBN("0")

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
    proof = newBN("0")
