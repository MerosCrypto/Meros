include MainGlobals

proc mainMerit() {.raises: [
    ValueError,
    ArgonError,
    MintError,
    EventError,
    BLSError,
    SodiumError,
    FinalAttributeError
].} =
    {.gcsafe.}:
        #Create the Merit.
        merit = newMerit(GENESIS, BLOCK_TIME, BLOCK_DIFFICULTY, LIVE_MERIT)

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
            proc (newBlock: Block): bool {.raises: [
                KeyError,
                ValueError,
                MintError,
                EventError,
                BLSError,
                SodiumError,
                FinalAttributeError
            ].} =
                result = true

                #Print that we're adding the Block.
                echo "Adding a new Block."

                #Verify the Verifications.
                for verif in newBlock.verifications.verifications:
                    if not lattice.lookup.hasKey(verif.hash.toString()):
                        echo "Failed to add the Block."
                        return false

                #Add the Block to the Merit.
                var rewards: Rewards
                try:
                    rewards = merit.processBlock(newBlock)
                except:
                    echo "Failed to add the Block."
                    return false

                #Add each Verification.
                for verif in newBlock.verifications.verifications:
                    #Discard the result since we already made sure the hash exists.
                    discard lattice.verify(merit, verif)

                #Create the Mints (which ends up minting a total of of 50000 EMB).
                #Nonce of the Mint.
                var mintNonce: uint
                for reward in rewards:
                    mintNonce = lattice.mint(
                        reward.key,
                        newBN(reward.score) * newBN(50) #This is a BN because 50 will end up as a much bigger number (decimals).
                    )

                    #If we have wallets...
                    if (wallet != nil) and (minerWallet != nil):
                        #Check if we're the one getting the reward.
                        if minerWallet.publicKey.toString() == reward.key:
                            #Claim the Reward.
                            var claim: Claim = newClaim(
                                mintNonce,
                                lattice.getAccount(wallet.address).height
                            )
                            #Sign the claim.
                            claim.sign(minerWallet, wallet)

                            #Emit it.
                            try:
                                events.get(
                                    proc (claim: Claim),
                                    "lattice.claim"
                                )(claim)
                            except:
                                raise newException(EventError, "Couldn't get and call lattice.receive.")

                echo "Successfully added the Block."
        )
