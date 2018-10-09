include MainGlobals

#Create the Merit.
merit = newMerit(GENESIS, BLOCK_TIME, BLOCK_DIFFICULTY, LIVE_MERIT)

#Mine a single block so there's Merit in the system.
block:
    var
        #Create a wallet to mine to.
        wallet: Wallet = newWallet()
        #Block var.
        newBlock: Block
        proof: uint = 0
        miners: seq[tuple[miner: string, amount: uint]] = @[(
            miner: wallet.address,
            amount: uint(100)
        )]

    while true:
        #Create a block.
        newBlock = newBlock(
            merit.blockchain.blocks[0].argon,
            1,
            getTime(),
            @[],
            newMerkleTree(@[]),
            $wallet.publicKey,
            proof,
            miners,
            wallet.sign(SHA512(miners.serialize(1)).toString())
        )

        #Try to add it.
        if not merit.processBlock(newBlock):
            #If it's invalid, increase the proof and continue.
            inc(proof)
            continue

        #Exit out of the loop once we've mined one block.
        break

    echo wallet.address & " has 100 Merit."
    echo "Its Private Key is " & $wallet.privateKey & "."
    echo ""

#Handle Verifications.
events.on(
    "merit.verification",
    proc (verif: Verification): bool {.raises: [ValueError].} =
        #Print that we're adding the node.
        echo "Adding a new Verification."

        #Add the Verification to the Lattice.
        lattice.verify(merit, verif.hash, verif.sender)
        echo "Successfully added the Verification."
        result = true
)
