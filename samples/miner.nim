#Number libs.
import lib/BN
import lib/Hex

#Time lib.
import lib/time as TimeFile

#Block, blockchain, and State libs.
import Reputation/Block
import Reputation/Blockchain
import Reputation/State

var
    #Blockchain var and creation.
    blockchain: Blockchain = newBlockchain("0")
    state: State = createState(blockchain)
    #Block var; defined here to stop a memory leak.
    newBlock: Block
    #Nonce, time, miner's address, and proof vars.
    nonce: BN = newBN("1")
    time: BN = getTime()
    miner: string = "Emb6tjjZ8McWvkd6TPGrZvEQBTDx2JRSezN269KoLso8D1zpGBga7v5TWetAVK"
    proof: BN = newBN("0")

echo "First balance: " & $state.getBalance(miner)

#mine the chain.
while true:
    echo "Looping... Balance of the miner is " & $state.getBalance(miner)

    #Create a block.
    newBlock = newBlock(nonce, time, miner, Hex.convert(proof))

    #Test it.
    if not blockchain.addBlock(newBlock):
        #If it's invalid, increase the proof and continue.
        inc(proof)
        continue

    #If it's valid, have the state process it.
    state.processBlock(newBlock)

    #Print that we mined a block!
    echo "Mined a block: " & $nonce

    #Finally, increase the nonce and update the timestamp.
    inc(nonce)
    time = getTime()
