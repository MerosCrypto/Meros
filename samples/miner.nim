#Number libs.
import lib/BN
import lib/Base

#Time lib.
import lib/Time as TimeFile

#SHA512 lib.
import lib/SHA512

#Merit lib.
import DB/Merit/Merit

#Wallet lib.
import Wallet/Wallet

#Serialization libs.
import Network/Serialize

proc main() =
    var
        #Create a wallet to mine to.
        wallet: Wallet = newWallet()
        #Get the address.
        miner: string = wallet.getAddress()
        #Get the publisher.
        publisher: string = $wallet.getPublicKey()
        #Merit var.
        merit: Merit = newMerit("mainnet")
        #Block var; defined here to stop a memory leak.
        newBlock: Block
        #Nonce, time, and proof vars.
        nonce: BN = newBN(1)
        time: BN = getTime()
        proof: BN = newBN()
        miners: seq[tuple[miner: string, percent: int]] = @[(
            miner: miner,
            percent: 1000
        )]

    echo "First balance: " & $merit.getBalance(miner)

    #Mine the chain.
    while true:
        echo "Looping..."

        #Update the time.
        time = getTime()

        #Create a block.
        newBlock = newBlock(
            nonce,
            time,
            @[],
            newMerkleTree(@[]),
            publisher,
            proof.toString(16),
            miners,
            wallet.sign(SHA512(miners.serialize(nonce)))
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
        echo "The miner's Merit is " & $merit.getBalance(miner) & "."

        #Finally, increase the nonce and reset the proof.
        inc(nonce)
        proof = newBN()

main()
