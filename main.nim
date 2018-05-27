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
    echo "Looping..."
    try:
        newBlock = createBlock(nonce, "1", Hex.convert(proof))
        try:
            blockchain.testBlock(newBlock)
        except:
            raise
        blockchain.addBlock(newBlock)
    except:
        inc(proof)
        continue
    echo "Mined a block: " & $nonce
    inc(nonce)
