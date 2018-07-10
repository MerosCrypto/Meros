#Number libs.
import lib/BN
import lib/Hex

#Time lib.
import lib/time as TimeFile

#Merit lib.
import Merit/Merit

var
    #Merit var.
    merit: Merit = newMerit("0")
    #Block var; defined here to stop a memory leak.
    newBlock: Block
    #Nonce, time, miner's address, and proof vars.
    nonce: BN = newBN("1")
    time: BN = getTime()
    miner: string = "Emb6tjjZ8McWvkd6TPGrZvEQBTDx2JRSezN269KoLso8D1zpGBga7v5TWetAVK"
    proof: BN = newBN("0")

echo "First balance: " & $merit.getBalance(miner)

#Mine the chain.
while true:
    echo "Looping..."

    #Create a block.
    newBlock = newBlock(nonce, time, miner, Hex.convert(proof))

    #Test it.
    if not merit.testBlock(newBlock):
        #If it's invalid, increase the proof and continue.
        inc(proof)
        continue

    #If it's valid, have the state process it.
    discard merit.processBlock(newBlock)

    #Print that we mined a block!
    echo "Mined a block: " & $nonce
    echo "Balance of the miner is " & $merit.getBalance(miner)

    #Finally, increase the nonce and update the timestamp.
    inc(nonce)
    time = getTime()
