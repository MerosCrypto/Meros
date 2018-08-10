#Number libs.
import lib/BN
import lib/Base

#Time lib.
import lib/Time as TimeFile

#Merit lib.
import DB/Merit/Merit

#Wallet lib.
import Wallet/Wallet

proc main() =
    var
        #Create a wallet to mine to.
        wallet: Wallet = newWallet()
        #Get the address.
        miner = wallet.getAddress()
        #Merit var.
        merit: Merit = newMerit("0")
        #Block var; defined here to stop a memory leak.
        newBlock: Block
        #Nonce, time, and proof vars.
        nonce: BN = newBN(1)
        time: BN = getTime()
        proof: BN = newBN()

    echo "First balance: " & $merit.getBalance(miner)

    #Mine the chain.
    while true:
        echo "Looping..."

        #Create a block.
        newBlock = newBlock(
            nonce,
            time,
            @[],
            newMerkleTree(@[]),
            proof.toString(16),
            @[(
                miner: miner,
                percent: 100.0
            )]
        )

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

        #Finally, increase the nonce, update the timestamp, and reset the proof.
        inc(nonce)
        time = getTime()
        proof = newBN()

main()
