include MainMerit

proc verify(entry: Entry) {.raises: [KeyError, ValueError, FinalAttributeError].} =
    if miner:
        #Verify the Entry.
        var verif: MemoryVerification = merit.verify(entry.hash)
        #Discard because it is known to be valid.
        discard lattice.verify(merit, verif)

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

proc mainLattice*() {.raises: [
    ValueError,
    MintError,
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

        #Handle Sends.
        events.on(
            "lattice.send",
            proc (send: Send): proc () {.raises: [
                ValueError,
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
