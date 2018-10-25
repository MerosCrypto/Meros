include MainGlobals

proc mainMerit*() {.raises: [
    ValueError,
    ArgonError,
    BLSError,
    SodiumError
].} =
    {.gcsafe.}:
        #Create the Merit.
        merit = newMerit(GENESIS, BLOCK_TIME, BLOCK_DIFFICULTY, LIVE_MERIT)
        #If we're mining...
        if miner:
            merit.setMinerWallet(minerKey)

        #Handle Verifications.
        events.on(
            "merit.verification",
            proc (verif: Verification): bool {.raises: [ValueError].} =
                #Print that we're adding the Verification.
                echo "Adding a new Verification."

                #Add the Verification to the Lattice.
                result = lattice.verify(merit, verif)
                if result:
                    echo "Successfully added the Verification."
                else:
                    echo "Failed to add the Verification."
        )

        #Handle full blocks.
        events.on(
            "merit.block",
            proc (newBlock: Block): bool {.raises: [KeyError, ValueError, BLSError, SodiumError].} =
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
                        discard lattice.verify(merit, verif)

                    echo "Successfully added the Block."
                else:
                    echo "Failed to add the Block."
        )
