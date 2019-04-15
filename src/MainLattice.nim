include MainMerit

#Creates and publishes a Verification.
proc verify(
    entry: Entry
) {.async.} =
    #Sleep for 100 microseconds to make sure this Verification is sent after ther Entry itself.
    await sleepAsync(100)

    #Make sure we're a Miner with Merit.
    if config.miner.initiated and (merit.state[config.miner.publicKey] > 0):
        #Make sure we didn't already Verify an Entry at this position.
        if lattice[entry.sender].entries[entry.nonce - lattice[entry.sender].confirmed].len != 1:
            return

        #Acquire the verify lock.
        while not tryAcquire(verifyLock):
            #While we can't acquire it, allow other async processes to run.
            await sleepAsync(1)

        #Verify the Entry.
        var verif: MemoryVerification = newMemoryVerificationObj(entry.hash)
        config.miner.sign(verif, verifications[config.miner.publicKey].height)

        #Add the verif to verifications.
        verifications.add(verif)

        #Release the verify lock.
        release(verifyLock)

        #Add the Verification to the Lattice.
        lattice.verify(merit, verif)

        #Broadcast the Verification.
        await network.broadcast(
            newMessage(
                MessageType.MemoryVerification,
                verif.serialize()
            )
        )

proc mainLattice() {.forceCheck: [].} =
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
        ): int {.forceCheck: [
            AddressError
        ].} =
            try:
                result = lattice[address].height
            except AddressError as e:
                raise e

        #Handle requests for an account's balance.
        functions.lattice.getBalance = proc (
            address: string
        ): BN {.forceCheck: [
            AddressError
        ].} =
            try:
                result = lattice[address].balance
            except AddressError as e:
                raise e

        #Handle requests for an Entry.
        functions.lattice.getEntryByHash = proc (
            hash: Hash[384]
        ): Entry {.forceCheck: [
            ValueError,
            IndexError,
            ArgonError,
            BLSError,
            EdPublicKeyError
        ].} =
            try:
                result = lattice[hash]
            except ValueError as e:
                raise e
            except IndexError as e:
                raise e
            except ArgonError as e:
                raise e
            except BLSError as e:
                raise e
            except EdPublicKeyError as e:
                raise e

        functions.lattice.getEntryByIndex = proc (
            index: LatticeIndex
        ): Entry {.forceCheck: [
            ValueError,
            IndexError
        ].} =
            try:
                result = lattice[index]
            except ValueError as e:
                raise e
            except IndexError as e:
                raise e

        #Handle Claims.
        functions.lattice.addClaim = proc (
            claim: Claim
        ) {.forceCheck: [
            ValueError,
            IndexError,
            GapError,
            AddressError,
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
                raise e
            #Account has an invalid address.
            except AddressError as e:
                echo "Failed to add the Claim."
                raise e
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
            except Exception:
                doAssert(false)

        #Handle Sends.
        functions.lattice.addSend = proc (
            send: Send
        ) {.forceCheck: [
            ValueError,
            IndexError,
            GapError,
            AddressError,
            EdPublicKeyError,
            SodiumError
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
                raise e
            #Account has an invalid address.
            except AddressError as e:
                echo "Failed to add the Send."
                raise e
            #Invalid Ed25519 Public Key.
            except EdPublicKeyError as e:
                echo "Failed to add the Send."
                raise e
            #BLSError.
            except BLSError as e:
                doAssert(false, "Couldn't add a Send due to a BLSError, which can only be thrown when adding a Claim: " & e.msg)

            echo "Successfully added the Send."

            #Create a Verification.
            try:
                asyncCheck verify(send)
            except Exception:
                doAssert(false)

            #If the Send is for us, Receive it.
            if wallet.initiated:
                if send.output == wallet.address:
                    #Create the Receive.
                    var recv: Receive
                    try:
                        recv = newReceive(
                            newLatticeIndex(
                                send.sender,
                                send.nonce
                            ),
                            lattice[wallet.address].height
                        )
                    except AddressError:
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
        ) {.forceCheck: [
            ValueError,
            IndexError,
            GapError,
            AddressError,
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
                raise e
            #Account has an invalid address.
            except AddressError as e:
                echo "Failed to add the Receive."
                raise e
            #Invalid Ed25519 Public Key.
            except EdPublicKeyError as e:
                echo "Failed to add the Receive."
                raise e
            #BLSError.
            except BLSError as e:
                doAssert(false, "Couldn't add a Send due to a BLSError, which can only be thrown when adding a Receive: " & e.msg)

            echo "Successfully added the Receive."

            #Create a Verification.
            try:
                asyncCheck verify(recv)
            except Exception:
                doAssert(false)

        #Handle Data.
        functions.lattice.addData = proc (
            data: Data
        ) {.forceCheck: [
            ValueError,
            IndexError,
            GapError,
            AddressError,
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
                raise e
            #Account has an invalid address.
            except AddressError as e:
                echo "Failed to add the Data."
                raise e
            #Invalid Ed25519 Public Key.
            except EdPublicKeyError as e:
                echo "Failed to add the Data."
                raise e
            #BLSError.
            except BLSError as e:
                doAssert(false, "Couldn't add a Send due to a BLSError, which can only be thrown when adding a Data: " & e.msg)

            echo "Successfully added the Data."

            #Create a Verification.
            try:
                asyncCheck verify(data)
            except Exception:
                doAssert(false)
