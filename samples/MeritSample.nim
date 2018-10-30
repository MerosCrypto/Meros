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
        #Create a Wallet.
        wallet: Wallet = newWallet()
        #Create a Wallet for signing Verifications.
        miner: MinerWallet = newMinerWallet()
        #Gensis var.
        genesis: string = "mainnet"
        #Merit var.
        merit: Merit = newMerit(genesis, 10, "cc".repeat(64), 50)
        #Block var; defined here to stop a memory leak.
        newBlock: Block
        #Last block hash, nonce, time, and proof vars.
        last: ArgonHash = merit.blockchain.blocks[0].argon
        nonce: uint = 1
        time: uint
        proof: uint = 0
        miners: Miners = @[(
            newMinerObj(
                miner.publicKey,
                100
            )
        )]
        #Verifications object.
        verifs: Verifications = newVerificationsObj()
    verifs.calculateSig()

    echo "First balance: " & $merit.state.getBalance(miner.publicKey)

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
            verifs,
            wallet.publicKey,
            proof,
            miners,
            wallet.sign(SHA512(miners.serialize(nonce)).toString())
        )

        #Try to add it.
        try:
            discard merit.processBlock(newBlock):
        except:
            #If it's invalid, increase the proof and continue.
            inc(proof)
            continue

        #If we didn't continue, the block was valid! Print that we mined a block!
        echo "Mined a block: " & $nonce
        echo "The miner's Merit is " & $merit.state.getBalance(miner.publicKey) & "."

        #Finally, update the last hash, increase the nonce, and reset the proof.
        last = newBlock.argon
        inc(nonce)
        proof = 0

main()
