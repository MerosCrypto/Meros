#Util lib.
import ../src/lib/Util

#Hash lib.
import ../src/lib/Hash

#MinerWallet lib.
import ../src/Wallet/MinerWallet

#Index object.
import ../src/Database/common/objects/IndexObj

#Verifications lib.
import ../src/Database/Verifications/Verifications

#Merit lib.
import ../src/Database/Merit/Merit

#Serialization libs.
import ../src/Network/Serialize/Merit/SerializeMiners

#String utils standard lib.
import strutils

#Main function is so these variables can be GC'd.
proc main() =
    var
        #Create a Wallet to mine to.
        miner: MinerWallet = newMinerWallet()
        #Gensis string.
        genesis: string = "sample"

        #Verifications.
        verifs: Verifications = newVerifications()
        #Merit.
        merit: Merit = newMerit(genesis, 10, "cc".repeat(64), 50)

        #Block.
        newBlock: Block
        #Nomce and the last block hash.
        nonce: uint = 1
        last: ArgonHash = merit.blockchain.blocks[0].hash
        #Indexes.
        indexes: seq[Index] = @[]
        #Miners object.
        miners: Miners = @[(
            newMinerObj(
                miner.publicKey,
                100
            )
        )]


    echo "First balance: " & $merit.state.getBalance(miner.publicKey)

    #Mine the chain.
    while true:
        #Create a block.
        newBlock = newBlock(
            verifs,
            nonce,
            last,
            indexes,
            miners
        )

        #Mine it.
        while true:
            try:
                #Add it.
                discard merit.processBlock(verifs, newBlock)
                #If we succeded, break.
                break
            except:
                #If we failed, print the proof we tried.
                echo "Proof " & $newBlock.header.proof & " failed."
                #Increase the proof.
                inc(newBlock)

        #Print that we mined a block.
        echo "Mined a block: " & $nonce
        #Print our balance.
        echo "The miner's Merit is " & $merit.state.getBalance(miner.publicKey) & "."

        #Increase the nonce.
        inc(nonce)
        #Update last.
        last = newBlock.hash

main()
