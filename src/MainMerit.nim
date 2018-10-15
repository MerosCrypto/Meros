include MainGlobals

proc mainMerit*() {.raises: [
    ValueError,
    RandomError,
    ArgonError,
    SodiumError,
    FinalAttributeError
].} =
    {.gcsafe.}:
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
                miners: Miners = @[(
                    newMinerObj(
                        wallet.address,
                        100
                    )
                )]

            while true:
                #Create a block.
                newBlock = newBlock(
                    merit.blockchain.blocks[0].argon,
                    1,
                    getTime(),
                    newVerificationsObj(),
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
            echo "Its Seed is " & $wallet.seed & "."
            echo ""

        #Handle Verifications.
        events.on(
            "merit.verification",
            proc (verif: Verification): bool {.raises: [ValueError].} =
                #Print that we're adding the Verification.
                echo "Adding a new Verification."

                #Add the Verification to the Lattice.
                result = lattice.verify(merit, verif.hash, verif.sender)
                if result:
                    echo "Successfully added the Verification."
                else:
                    echo "Failed to add the Verification."
        )

        #Handle full blocks.
        events.on(
            "merit.block",
            proc (newBlock: Block): bool {.raises: [KeyError, ValueError].} =
                result = true

                #Print that we're adding the Block.
                echo "Adding a new Block."

                #Verify the Verifications.
                for verif in newBlock.verifications.verifications:
                    if not lattice.lookup.hasKey(verif.hash.toString()):
                        echo "Failed to add the Block."
                        return false

                #Add the Block to the Merit.
                if merit.processBlock(newBlock):
                    #Add each Verification.
                    for verif in newBlock.verifications.verifications:
                        #Discard the result since we already made sure the hash exists.
                        discard lattice.verify(merit, verif.hash, verif.sender)

                    echo "Successfully added the Block."
                else:
                    echo "Failed to add the Block."
        )
