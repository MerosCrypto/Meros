import Wallet/PrivateKey
import Wallet/PublicKey

var
    privKey: PrivateKey = newPrivateKey()
    pubKey: PublicKey = newPublicKey(privKey)
    privKey2: PrivateKey = newPrivateKey()
    pubKey2: PublicKey = newPublicKey(privKey2)

var str: string = "test"

echo pubKey.verify(str, privKey.sign(str))
echo pubKey2.verify(str, privKey.sign(str))

discard """
# This is currently a miner. It creates a Blockchain and adds blocks.

#Library files.
import lib/BN
import lib/Hex

#Block, blockchain, and State file.
import Reputation/Block
import Reputation/Blockchain
import Reputation/State

var
    #Create a blockchain.
    blockchain: Blockchain = createBlockchain("0")
    state: State = createState(blockchain)
    #Stop memory leaking in the below loop.
    newBlock: Block
    #Nonce and proof vars.
    nonce: BN = newBN("1")
    proof: BN = newBN("0")

echo "First balance: " & $state.getBalance("2")

#mine the chain.
while true:
    echo "Looping... Balance of the miner is " & $state.getBalance("2")
    try:
        #Create a block.
        newBlock = createBlock(nonce, "2", Hex.convert(proof))
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
        state.processBlock(newBlock)
    except:
        #If it didn't, increase the proof and continue.
        inc(proof)
        continue
    #If we never errored, that means we mined a block. Print it!
    echo "Mined a block: " & $nonce
    #Increase the nonce.
    inc(nonce)
"""
