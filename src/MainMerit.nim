include MainGlobals

proc mainMerit() {.raises: [
    ValueError,
    AsyncError,
    ArgonError,
    BLSError
].} =
    {.gcsafe.}:
        #Create the Merit.
        merit = newMerit(GENESIS, BLOCK_TIME, BLOCK_DIFFICULTY, LIVE_MERIT)

        #Handle requests for the current height.
        events.on(
            "merit.getHeight",
            proc (): uint {.raises: [].} =
                merit.blockchain.height
        )

        #Handle requests for the current Difficulty.
        events.on(
            "merit.getDifficulty",
            proc (): BN {.raises: [].} =
                merit.blockchain.difficulties[^1].difficulty
        )

        #Handle requests for a Block.
        events.on(
            "merit.getBlock",
            proc (nonce: uint): Block {.raises: [].} =
                merit.blockchain.blocks[int(nonce)]
        )

        #Handle Verifications.
        events.on(
            "merit.verification",
            proc (verif: MemoryVerification): bool {.raises: [ValueError, BLSError].} =
                result = true

                #Print that we're adding the Verification.
                echo "Adding a new Verification."

                #Verify the signature.
                verif.signature.setAggregationInfo(
                    newBLSAggregationInfo(verif.verifier, verif.hash.toString())
                )
                if not verif.signature.verify():
                    return false

                #Add the Verification to the Lattice.
                result = lattice.verify(merit, verif)
                if not result:
                    echo "Failed to add the Verification."

                #Add the Verification to the unarchived set.
                lattice.unarchive(verif)
                echo "Successfully added the Verification."
        )

        #Handle full blocks.
        try:
            events.on(
                "merit.block",
                proc (newBlock: Block): Future[bool] {.async.} =
                    result = true

                    #Print that we're adding the Block.
                    echo "Adding a new Block."

                    #If we're connected to other people, sync the Block.
                    if network.clients.clients.len > 0:
                        if not await newBlock.sync(network, network.clients.clients[0]):
                            echo "Failed to add the Block."
                            return false

                    #Verify the Verifications.
                    if not newBlock.verifications.verify():
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
                        #Archive the verification.
                        lattice.archive(verif)

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
                                    if not events.get(
                                        proc (claim: Claim): bool,
                                        "lattice.claim"
                                    )(claim):
                                        raise newException(Exception, "")
                                except:
                                    raise newException(EventError, "Couldn't get and call lattice.claim.")

                                #Broadcast it.
                                network.broadcast(
                                    newMessage(
                                        NETWORK_ID,
                                        NETWORK_PROTOCOL,
                                        MessageType.Claim,
                                        claim.serialize()
                                    )
                                )

                    echo "Successfully added the Block."

                    #Broadcast the Block.
                    try:
                        rpc.events.get(
                            proc (msgType: MessageType, msg: string),
                            "network.broadcast"
                        )(MessageType.Block, newBlock.serialize())
                    except:
                        echo "Failed to broadcast the Block."
            )
        except:
            raise newException(AsyncError, "Couldn't add merit.block (async) to the EventEmitter.")
