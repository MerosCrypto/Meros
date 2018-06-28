import lib/SHA512

import Wallet/PrivateKey
#This should be PublicKey in the future.
import lib/SECP256K1Wrapper

var privKey = newPrivateKey()
var privKey2 = newPrivateKey()
var
    str: string = "test"
    hash: string = SHA512(str).substr(0, 31)

#.secret will be private in the future.
echo secpVerify(hash, secpPublicKey(privKey.secret), privKey.sign(str))
echo secpVerify(hash, secpPublicKey(privKey2.secret), privKey.sign(str))

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
