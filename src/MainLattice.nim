include MainMerit

#Creates and publishes a Verification.
proc verify(entry: Entry) {.raises: [KeyError, ValueError, FinalAttributeError].} =
    #Make sure we're a Miner with Merit.
    if (miner) and (merit.state.getBalance(minerWallet.publicKey) > uint(0)):
        #Verify the Entry.
        var verif: MemoryVerification = newMemoryVerification(entry.hash)
        minerWallet.sign(verif)

        #Discard lattice.verify because it is known to return true.
        discard lattice.verify(merit, verif)
        #Add the Verification to the unarchived set.
        lattice.unarchive(verif)

        #Broadcast the Verification.
        try:
            events.get(
                proc (msgType: MessageType, msg: string),
                "network.broadcast"
            )(
                MessageType.Verification,
                verif.serialize()
            )
        except:
            echo "Failed to broadcast the Verification."

proc mainLattice() {.raises: [
    ValueError,
    MintError,
    EventError,
    BLSError,
    SodiumError,
    FinalAttributeError
].} =
    {.gcsafe.}:
        #Create the Lattice.
        lattice = newLattice(
            TRANSACTION_DIFFICULTY,
            DATA_DIFFICULTY
        )

        #Create the Genesis Mint.
        genesisMint = lattice.mint(
            MINT_PUBKEY,
            newBN(MINT_AMOUNT)
        )

        #Handle Claims.
        events.on(
            "lattice.claim",
            proc (claim: Claim): proc() {.raises: [].} =
                #Print that we're adding the Entry.
                echo "Adding a new Claim."

                #Add the Claim.
                if lattice.add(
                    merit,
                    claim
                ):
                    echo "Successfully added the Claim."

                    #If it worked, broadcast the Claim.
                    try:
                        rpc.events.get(
                            proc (msgType: MessageType, msg: string),
                            "network.broadcast"
                        )(MessageType.Claim, claim.serialize())
                    except:
                        echo "Failed to broadcast the Claim."

                    #Create a Verification.
                    verify(claim)
                else:
                    echo "Failed to add the Claim."
                echo ""
        )

        #Handle Sends.
        events.on(
            "lattice.send",
            proc (send: Send): proc () {.raises: [
                ValueError,
                EventError,
                BLSError,
                SodiumError,
                FinalAttributeError
            ].} =
                #Print that we're adding the Entry.
                echo "Adding a new Send."

                #Add the Send.
                if lattice.add(
                    merit,
                    send
                ):
                    echo "Successfully added the Send."

                    #If it worked, broadcast the Send.
                    try:
                        rpc.events.get(
                            proc (msgType: MessageType, msg: string),
                            "network.broadcast"
                        )(MessageType.Send, send.serialize())
                    except:
                        echo "Failed to broadcast the Send."

                    #If the Send is for us, Receive it.
                    if wallet != nil:
                        if send.output == wallet.address:
                            #Create the Receive.
                            var recv: Receive = newReceive(
                                newIndex(
                                    send.sender,
                                    send.nonce
                                ),
                                lattice.getAccount(wallet.address).height
                            )
                            #Sign it.
                            wallet.sign(recv)

                            #Emit it.
                            try:
                                events.get(
                                    proc (recv: Receive),
                                    "lattice.receive"
                                )(recv)
                            except:
                                raise newException(EventError, "Couldn't get and call lattice.receive.")

                    #Create a Verification.
                    verify(send)
                else:
                    echo "Failed to add the Send."
                echo ""
        )

        #Handle Receives.
        events.on(
            "lattice.receive",
            proc (recv: Receive) {.raises: [
                ValueError,
                BLSError,
                SodiumError,
                FinalAttributeError
            ].} =
                #Print that we're adding the Entry.
                echo "Adding a new Receive."

                #Add the Receive.
                if lattice.add(
                    merit,
                    recv
                ):
                    echo "Successfully added the Receive."

                    #If it worked, broadcast the Receive.
                    try:
                        rpc.events.get(
                            proc (msgType: MessageType, msg: string),
                            "network.broadcast"
                        )(MessageType.Receive, recv.serialize())
                    except:
                        echo "Failed to broadcast the Receive."

                    #Create a Verification.
                    verify(recv)
                else:
                    echo "Failed to add the Receive."
                echo ""
        )

        #Handle Data.
        events.on(
            "lattice.data",
            proc (
                msg: Message,
                data: Data
            ) {.raises: [
                ValueError,
                BLSError,
                SodiumError,
                FinalAttributeError
            ].} =
                #Print that we're adding the Entry.
                echo "Adding a new Data."

                #Add the Data.
                if lattice.add(
                    merit,
                    data
                ):
                    echo "Successfully added the Data."

                    #If it worked, broadcast the Data.
                    try:
                        rpc.events.get(
                            proc (msgType: MessageType, msg: string),
                            "network.broadcast"
                        )(MessageType.Data, data.serialize())
                    except:
                        echo "Failed to broadcast the Data."

                    #Create a Verification.
                    verify(data)
                else:
                    echo "Failed to add the Data."
                echo ""
        )

        #Handle requests for an account's height.
        events.on(
            "lattice.getHeight",
            proc (account: string): uint {.raises: [ValueError].} =
                lattice.getAccount(account).height
        )

        #Handle requests for an account's balance.
        events.on(
            "lattice.getBalance",
            proc (account: string): BN {.raises: [ValueError].} =
                lattice.getAccount(account).balance
        )

        #Print the Seed and address of the address holding the coins.
        echo MINT_PUBKEY & " was sent " & MINT_AMOUNT & " EMB from \"minter\".\r\n" &
            "Its Private Key is " & MINT_PRIVKEY & ".\r\n"
