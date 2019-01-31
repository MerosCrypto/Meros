include MainMerit

#Creates and publishes a Verification.
proc verify(entry: Entry) {.async.} =
    #Sleep for 100 microseconds to make sure this Verification is sent after ther Entry itself.
    await sleepAsync(100)

    #Make sure we're a Miner with Merit.
    if (miner) and (merit.state.getBalance(minerWallet.publicKey) > uint(0)):
        #Make sure we didn't already Verify an Entry at this position.
        if lattice.accounts[entry.sender].entries[int(entry.nonce)].len != 1:
            return

        #Acquire the verify lock.
        while not tryAcquire(verifyLock):
            #While we can't acquire it, allow other async processes to run.
            await sleepAsync(1)

        #Verify the Entry.
        var verif: MemoryVerification = newMemoryVerificationObj(entry.hash)
        minerWallet.sign(verif, verifications[minerWallet.publicKey.toString()].height)

        #Add the verif to verifications.
        verifications.add(verif)

        #Release the verify lock.
        release(verifyLock)

        #Discard lattice.verify because it is known to return true.
        discard lattice.verify(merit, verif)

        #Broadcast the Verification.
        await network.broadcast(
            newMessage(
                MessageType.MemoryVerification,
                verif.serialize()
            )
        )

proc mainLattice() {.raises: [ValueError].} =
    {.gcsafe.}:
        #Create the Lattice.
        lattice = newLattice(
            TRANSACTION_DIFFICULTY,
            DATA_DIFFICULTY
        )

        #Handle requests for an account's height.
        functions.lattice.getHeight = proc (account: string): uint {.raises: [ValueError].} =
            lattice.getAccount(account).height

        #Handle requests for an account's balance.
        functions.lattice.getBalance = proc (account: string): BN {.raises: [ValueError].} =
            lattice.getAccount(account).balance

        #Handle requests for an Entry.
        functions.lattice.getEntryByHash = proc (hash: string): Entry {.raises: [KeyError, ValueError].} =
            lattice[hash]

        functions.lattice.getEntryByIndex = proc (index: Index): Entry {.raises: [ValueError].} =
            lattice[index]

        #Handle Claims.
        functions.lattice.addClaim = proc (claim: Claim): bool {.raises: [
            ValueError,
            AsyncError,
            BLSError,
            SodiumError
        ].} =
            #Print that we're adding the Entry.
            echo "Adding a new Claim."

            #Add the Claim.
            if lattice.add(
                merit,
                claim
            ):
                result = true
                echo "Successfully added the Claim."

                #Create a Verification.
                try:
                    asyncCheck verify(claim)
                except:
                    raise newException(AsyncError, "Couldn't verify an entry.")
            else:
                result = false
                echo "Failed to add the Claim."
            echo ""

        #Handle Sends.
        functions.lattice.addSend = proc (send: Send): bool {.raises: [
            ValueError,
            EventError,
            AsyncError,
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
                result = true
                echo "Successfully added the Send."

                #Create a Verification.
                try:
                    asyncCheck verify(send)
                except:
                    raise newException(AsyncError, "Couldn't verify an entry.")

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

                        try:
                            #Emit it.
                            if functions.lattice.addReceive(recv):
                                #Broadcast it.
                                asyncCheck network.broadcast(
                                    newMessage(
                                        MessageType.Receive,
                                        recv.serialize()
                                    )
                                )
                        except:
                            raise newException(EventError, "Couldn't get and call lattice.receive.")
            else:
                result = false
                echo "Failed to add the Send."
            echo ""


        #Handle Receives.
        functions.lattice.addReceive = proc (recv: Receive): bool {.raises: [
            ValueError,
            AsyncError,
            BLSError,
            SodiumError
        ].} =
            #Print that we're adding the Entry.
            echo "Adding a new Receive."

            #Add the Receive.
            if lattice.add(
                merit,
                recv
            ):
                result = true
                echo "Successfully added the Receive."

                #Create a Verification.
                try:
                    asyncCheck verify(recv)
                except:
                    raise newException(AsyncError, "Couldn't verify an entry.")
            else:
                result = false
                echo "Failed to add the Receive."
            echo ""

        #Handle Data.
        functions.lattice.addData = proc (data: Data): bool {.raises: [
            ValueError,
            AsyncError,
            BLSError,
            SodiumError
        ].} =
            #Print that we're adding the Entry.
            echo "Adding a new Data."

            #Add the Data.
            if lattice.add(
                merit,
                data
            ):
                result = true
                echo "Successfully added the Data."

                #Create a Verification.
                try:
                    asyncCheck verify(data)
                except:
                    raise newException(AsyncError, "Couldn't verify an entry.")
            else:
                result = false
                echo "Failed to add the Data."
            echo ""
