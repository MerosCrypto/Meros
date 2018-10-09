#Util lib.
import ../src/lib/Util

#Hash lib.
import ../src/lib/Hash

#Wallet lib.
import ../src/Wallet/Wallet

#Merit lib.
import ../src/Database/Merit/Merit

#Serialization libs.
import ../src/Network/Serialize/SerializeMiners

#String utils standard lib.
import strutils

#Main function is so these varriables can be GC'd.
proc main() =
    var
        #Create a wallet to mine to.
        wallet: Wallet = newWallet()
        #Get the publisher.
        publisher: string = $wallet.publicKey
        #Gensis var.
        genesis: string = "mainnet"
        #Merit var.
        merit: Merit = newMerit(genesis, 10, "cc".repeat(64), 50)
        #Block var; defined here to stop a memory leak.
        newBlock: Block
        #Last block hash, nonce, time, and proof vars.
        last: ArgonHash = merit.blockchain.blocks[0].argon
        nonce: int = 1
        time: uint
        proof: uint = 0
        miners: seq[tuple[miner: string, amount: uint]] = @[(
            miner: wallet.address,
            amount: uint(100)
        )]

    echo "First balance: " & $merit.state.getBalance(wallet.address)

    #Mine the chain.
    while true:
        echo "Looping with a proof of: " & $proof

        #Update the time.
        time = getTime()

        #Create a block.
        newBlock = newBlock(
            last,
            nonce,
            time,
            @[],
            newMerkleTree(@[]),
            publisher,
            proof,
            miners,
            wallet.sign(SHA512(miners.serialize(nonce)).toString())
        )

        #Try to add it.
        if not merit.processBlock(newBlock):
            #If it's invalid, increase the proof and continue.
            inc(proof)
            continue

        #If we didn't continue, the block was valid! Print that we mined a block!
        echo "Mined a block: " & $nonce
        echo "The miner's Merit is " & $merit.state.getBalance(wallet.address) & "."

        #Finally, update the last hash, increase the nonce, and reset the proof.
        last = newBlock.argon
        inc(nonce)
        proof = 0

main()
