# This is currently a miner. It creates a Blockchain and adds blocks.

#Library files.
import lib/BN
import lib/Hex

#Block and blockchain file.
import Reputation/Block
import Reputation/Blockchain
import Reputation/State

var
    #Create a blockchain.
    blockchain: Blockchain = createBlockchain("0")
    #Stop memory leaking in the below loop.
    newBlock: Block
    #Nonce and proof vars.
    nonce: BN = newBN("1")
    proof: BN = newBN("0")

#mine the chain.
while true:
    echo "Looping..."
    try:
        #Create a block.
        newBlock = createBlock(nonce, "1", Hex.convert(proof))
        #Test it.
        try:
            blockchain.testBlock(newBlock)
        except:
            #We don't have an error handler for testBlock other than the existing one.
            #It's really for Threads, which will be added later.
            #Just raise it for now.
            raise
        #Add the block if the test passed.
        blockchain.addBlock(newBlock)
    except:
        #If it didn't, increase the proof and continue.
        inc(proof)
        continue
    #If we never errored, that means we mined a block. Print it!
    echo "Mined a block: " & $nonce
    #Increase the nonce.
    inc(nonce)
