#Util lib.
import ../src/lib/Util

#Hash lib.
import ../src/lib/Hash

#Merit lib.
import ../src/Database/Merit/Merit

#Serialization libs.
import ../src/Network/Serialize/Merit/SerializeMiners

#String utils standard lib.
import strutils

#Main function is so these varriables can be GC'd.
proc main() =
    var
        #Create a Wallet for signing Verifications.
        miner: MinerWallet = newMinerWallet()
        #Gensis string.
        genesis: string = "mainnet"
        #Merit.
        merit: Merit = newMerit(genesis, 10, "cc".repeat(64), 50)
        #Block.
        newBlock: Block
        #Noce and the last block hash.
        nonce: uint = 1
        last: ArgonHash = merit.blockchain.blocks[0].argon
        #Verifications object.
        verifs: Verifications = newVerificationsObj()
        #Miners object.
        miners: Miners = @[(
            newMinerObj(
                miner.publicKey,
                100
            )
        )]
    #Calculate the Verifications' signature.
    verifs.calculateSig()

    echo "First balance: " & $merit.state.getBalance(miner.publicKey)

    #Mine the chain.
    while true:
        #Create a block.
        newBlock = newBlock(
            nonce,
            last,
            verifs,
            miners
        )

        #Mine it.
        while true:
            try:
                #Add it.
                discard merit.processBlock(newBlock)
                #If we succeded, break.
                break
            except:
                #If we failed, print the proof we tried.
                echo "Proof " & $newBlock.proof & " failed."
                #Increase the proof.
                inc(newBlock)

        #Print that we mined a block.
        echo "Mined a block: " & $nonce
        #Print our balance.
        echo "The miner's Merit is " & $merit.state.getBalance(miner.publicKey) & "."

        #Increase the nonce.
        inc(nonce)
        #Update last.
        last = newBlock.argon

main()
