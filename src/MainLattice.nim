include MainMerit

#Creates and publishes a Verification.
proc verify(
    entry: Entry
) {.async.} =
    #Sleep for 100 microseconds to make sure this Verification is sent after ther Entry itself.
    await sleepAsync(100)

    #Make sure we're a Miner with Merit.
    if (not config.miner.isNil) and (merit.state[config.miner.publicKey] > 0):
        #Make sure we didn't already Verify an Entry at this position.
        if lattice[entry.sender].entries[entry.nonce - lattice[entry.sender].confirmed].len != 1:
            return

        #Acquire the verify lock.
        while not tryAcquire(verifyLock):
            #While we can't acquire it, allow other async processes to run.
            await sleepAsync(1)

        #Verify the Entry.
        var verif: MemoryVerification = newMemoryVerificationObj(entry.hash)
        config.miner.sign(verif, verifications[config.miner.publicKey.toString()].height)

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

proc mainLattice() {.raises: [
    ValueError,
    IndexError,
    GapError,
    EdPublicKeyError,
    BLSError
].} =
    {.gcsafe.}:
        #Create the Lattice.
        lattice = newLattice(
            functions.database,
            verifications,
            merit,
            TRANSACTION_DIFFICULTY,
            DATA_DIFFICULTY
        )

        #Handle requests for an account's height.
        functions.lattice.getHeight = proc (
            address: string
        ): int {.raises: [].} =
            lattice[address].height

        #Handle requests for an account's balance.
        functions.lattice.getBalance = proc (
            address: string
        ): BN {.raises: [].} =
            lattice[address].balance

        #Handle requests for an Entry.
        functions.lattice.getEntryByHash = proc (
            hash: Hash[384]
        ): Entry {.raises: [
            ValueError,
            ArgonError,
            BLSError,
            EdPublicKeyError
        ].} =
            try:
                lattice[hash]
            except ValueError as e:
                raise e
            except ArgonError as e:
                raise e
            except BLSError as e:
                raise e
            except EdPublicKeyError as e:
                raise e

        functions.lattice.getEntryByIndex = proc (
            index: LatticeIndex
        ): Entry {.raises: [
            ValueError,
            IndexError
        ].} =
            try:
                lattice[index]
            except ValueError as e:
                raise e
            except IndexError as e:
                raise e

        #Handle Claims.
        functions.lattice.addClaim = proc (
            claim: Claim
        ) {.raises: [
            ValueError,
            IndexError,
            GapError,
            EdPublicKeyError,
            BLSError
        ].} =
            #Print that we're adding the Claim.
            echo "Adding a new Claim."

            #Add the Claim.
            try:
                lattice.add(claim)
            #Invalid Ed25519 Signature or invalid BLS Signature OR data already exists.
            except ValueError as e:
                echo "Failed to add the Claim."
                raise e
            #Competing Entry already verified at this position.
            except IndexError as e:
                echo "Failed to add the Claim."
                raise e
            #Missing Entries before this Entry.
            except GapError as e:
                echo "Failed to add the Claim."
                discard
            #Invalid Ed25519 Public Key.
            except EdPublicKeyError as e:
                echo "Failed to add the Claim."
                raise e
            #BLS lib threw.
            except BLSError as e:
                echo "Failed to add the Claim."
                raise e

            echo "Successfully added the Claim."

            #Create a Verification.
            try:
                asyncCheck verify(claim)
            except:
                raise newException(AsyncError, "Couldn't verify a Claim.")

        #Handle Sends.
        functions.lattice.addSend = proc (
            send: Send
        ) {.raises: [
            ValueError,
            IndexError,
            GapError,
            EdPublicKeyError
        ].} =
            #Print that we're adding the Send.
            echo "Adding a new Send."

            #Add the Send.
            try:
                lattice.add(send)
            #Invalid Ed25519 Signature OR data already exists.
            except ValueError as e:
                echo "Failed to add the Send."
                raise e
            #Competing Entry already verified at this position.
            except IndexError as e:
                echo "Failed to add the Send."
                raise e
            #Missing Entries before this Entry.
            except GapError as e:
                echo "Failed to add the Send."
                discard
            #Invalid Ed25519 Public Key.
            except EdPublicKeyError as e:
                echo "Failed to add the Send."
                raise e

            echo "Successfully added the Send."

            #Create a Verification.
            try:
                asyncCheck verify(send)
            except:
                raise newException(AsyncError, "Couldn't verify a Send.")

            #If the Send is for us, Receive it.
            if wallet.initiated:
                if send.output == wallet.address:
                    #Create the Receive.
                    var recv: Receive
                    try:
                        recv = newReceive(
                            newIndex(
                                send.sender,
                                send.nonce
                            ),
                            lattice[wallet.address].height
                        )
                    except AddressError as e:
                        doAssert(false, "One of our Wallets has an invalid Address.")

                    #Sign it.
                    try:
                        wallet.sign(recv)
                    except SodiumError as e:
                        raise e

                    discard """
                        #Emit it.
                        functions.lattice.addReceive(recv)
                        #Broadcast it.
                        asyncCheck network.broadcast(
                            newMessage(
                                MessageType.Receive,
                                recv.serialize()
                            )
                        )
                    """

        #Handle Receives.
        functions.lattice.addReceive = proc (
            recv: Receive
        ) {.raises: [
            ValueError,
            IndexError,
            GapError,
            EdPublicKeyError
        ].} =
            #Print that we're adding the Receive.
            echo "Adding a new Receive."

            #Add the Receive.
            try:
                lattice.add(recv)
            #Invalid Ed25519 Signature OR data already exists.
            except ValueError as e:
                echo "Failed to add the Receive."
                raise e
            #Competing Entry already verified at this position.
            except IndexError as e:
                echo "Failed to add the Receive."
                raise e
            #Missing Entries before this Entry.
            except GapError as e:
                echo "Failed to add the Receive."
                discard
            #Invalid Ed25519 Public Key.
            except EdPublicKeyError as e:
                echo "Failed to add the Receive."
                raise e

            echo "Successfully added the Receive."

            #Create a Verification.
            try:
                asyncCheck verify(recv)
            except:
                raise newException(AsyncError, "Couldn't verify a Receive.")

        #Handle Data.
        functions.lattice.addData = proc (
            data: Data
        ) {.raises: [
            ValueError,
            IndexError,
            GapError,
            EdPublicKeyError
        ].} =
            #Print that we're adding the Data.
            echo "Adding a new Data."

            #Add the Data.
            try:
                lattice.add(data)
            #Invalid Ed25519 Signature OR data already exists.
            except ValueError as e:
                echo "Failed to add the Data."
                raise e
            #Competing Entry already verified at this position.
            except IndexError as e:
                echo "Failed to add the Data."
                raise e
            #Missing Entries before this Entry.
            except GapError as e:
                echo "Failed to add the Data."
                discard
            #Invalid Ed25519 Public Key.
            except EdPublicKeyError as e:
                echo "Failed to add the Data."
                raise e

            echo "Successfully added the Data."

            #Create a Verification.
            try:
                asyncCheck verify(data)
            except:
                raise newException(AsyncError, "Couldn't verify a Data.")
