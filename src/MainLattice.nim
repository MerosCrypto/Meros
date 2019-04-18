include MainMerit

#Creates and publishes a Verification.
proc verify(
    entry: Entry
) {.forceCheck: [], async.} =
    #Sleep for 100 microseconds to make sure this Verification is sent after ther Entry itself.
    try:
        await sleepAsync(100)
    except Exception as e:
        doAssert(false, "Couldn't sleep for 0.1 seconds before verifying an Entry: " & e.msg)

    #Make sure we're a Miner with Merit.
    if config.miner.initiated and (merit.state[config.miner.publicKey] > 0):
        #Make sure we didn't already verify an Entry at the same Index.
        try:
            if lattice[entry.sender].entries[entry.nonce - lattice[entry.sender].confirmed].len != 1:
                return
        except AddressError:
            doAssert(false, "Tried to verify an Entry who's sender was an invalid address.")

        #Acquire the verify lock.
        while not tryAcquire(verifyLock):
            #While we can't acquire it, allow other async processes to run.
            try:
                await sleepAsync(1)
            except Exception as e:
                doAssert(false, "Couldn't sleep for 0.001 seconds after failing to acqure the lock: " & e.msg)

        #Verify the Entry.
        var verif: MemoryVerification = newMemoryVerificationObj(entry.hash)
        try:
            config.miner.sign(verif, verifications[config.miner.publicKey].height)
        except BLSError as e:
            doAssert(false, "Couldn't create a MemoryVerification due to a BLSError: " & e.msg)

        #Add the verif to verifications.
        try:
            verifications.add(verif)
        except IndexError as e:
            doAssert(false, "Created a MemoryVerification which we already added: " & e.msg)
        except GapError as e:
            doAssert(false, "Created a MemoryVerification with an invalid nonce: " & e.msg)
        except MeritRemoval as e:
            doAssert(false, "Created a MemoryVerification which causes a Merit Removal: " & e.msg)

        #Release the verify lock.
        release(verifyLock)

        #Add the Verification to the Lattice.
        try:
            lattice.verify(merit, verif)
        except ValueError as e:
            doAssert(false, "Tried verifying an Entry when we didn't have Merit/tried verifying a non-existant/dated Entry: " & e.msg)
        except IndexError as e:
            doAssert(false, "Created a MemoryVerification which we already added: " & e.msg)

        #Broadcast the Verification.
        functions.network.broadcast(
            MessageType.MemoryVerification,
            verif.serialize()
        )

proc mainLattice() {.forceCheck: [].} =
    {.gcsafe.}:
        #Create the Lattice.
        lattice = newLattice(
            functions.database,
            verifications,
            merit,
            SEND_DIFFICULTY,
            DATA_DIFFICULTY
        )

        #Handle requests for the Difficulties.
        functions.lattice.getDifficulties = proc (): Difficulties {.forceCheck: [].} =
            lattice.difficulties

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
            IndexError
        ].} =
            try:
                result = lattice[hash]
            except IndexError as e:
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
                raise e
            #Competing Entry already verified at this position.
            except IndexError as e:
                raise e
            #Missing Entries before this Entry.
            except GapError as e:
                raise e
            #Account has an invalid address.
            except AddressError as e:
                raise e
            #Invalid Ed25519 Public Key.
            except EdPublicKeyError as e:
                raise e
            #BLS lib threw.
            except BLSError as e:
                raise e

            echo "Successfully added the Claim."

            #Create a Verification.
            try:
                asyncCheck verify(claim)
            except Exception as e:
                doAssert(false, "Verify threw an Exception despite not naturally throwing anything: " & e.msg)

        #Handle Sends.
        functions.lattice.addSend = proc (
            send: Send
        ) {.forceCheck: [
            ValueError,
            IndexError,
            GapError,
            AddressError,
            EdPublicKeyError
        ].} =
            #Print that we're adding the Send.
            echo "Adding a new Send."

            #Add the Send.
            try:
                lattice.add(send)
            #Invalid Ed25519 Signature OR data already exists.
            except ValueError as e:
                raise e
            #Competing Entry already verified at this position.
            except IndexError as e:
                raise e
            #Missing Entries before this Entry.
            except GapError as e:
                raise e
            #Account has an invalid address.
            except AddressError as e:
                raise e
            #Invalid Ed25519 Public Key.
            except EdPublicKeyError as e:
                raise e
            #BLSError.
            except BLSError as e:
                doAssert(false, "Couldn't add a Send due to a BLSError, which can only be thrown when adding a Claim: " & e.msg)

            echo "Successfully added the Send."

            #Create a Verification.
            try:
                asyncCheck verify(send)
            except Exception as e:
                doAssert(false, "Verify threw an Exception despite not naturally throwing anything: " & e.msg)

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
                    except AddressError as e:
                        doAssert(false, "One of our Wallets (" & wallet.address & ") has an invalid Address: " & e.msg)

                    #Sign it.
                    try:
                        wallet.sign(recv)
                    except SodiumError as e:
                        doAssert(false, "Failed to sign a Receive for a Send: " & e.msg)

                    #Emit it.
                    try:
                        functions.lattice.addReceive(recv)
                    except ValueError:
                        #The signature was either invalid or the Receive already existed.
                        #If the signature was invalid, we should doAssert(false).
                        #Else, we should discard.
                        #Until we add DataExists, we can't safely doAssert(false).
                        #doAssert(false, "Created a Receive with an invalid signature: " & e.msg)
                        discard
                    except IndexError:
                        discard
                    except GapError as e:
                        doAssert(false, "Created Receive has a nonce ahead of the height: " & e.msg)
                    except AddressError as e:
                        doAssert(false, "Created Receive has an invalid sender address, detected when adding: " & e.msg)
                    except EdPublicKeyError as e:
                        doAssert(false, "Created Receive's sender doesn't decode to a valid Public Key: " & e.msg)

                    #Broadcast it.
                    var serialized: string
                    try:
                        serialized = recv.serialize()
                    except AddressError as e:
                        doAssert(false, "Created Receive has an invalid sender address, detected when serializing: " & e.msg)
                    functions.network.broadcast(
                        MessageType.Receive,
                        serialized
                    )

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
                raise e
            #Competing Entry already verified at this position.
            except IndexError as e:
                raise e
            #Missing Entries before this Entry.
            except GapError as e:
                raise e
            #Account has an invalid address.
            except AddressError as e:
                raise e
            #Invalid Ed25519 Public Key.
            except EdPublicKeyError as e:
                raise e
            #BLSError.
            except BLSError as e:
                doAssert(false, "Couldn't add a Send due to a BLSError, which can only be thrown when adding a Receive: " & e.msg)

            echo "Successfully added the Receive."

            #Create a Verification.
            try:
                asyncCheck verify(recv)
            except Exception as e:
                doAssert(false, "Verify threw an Exception despite not naturally throwing anything: " & e.msg)

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
                raise e
            #Competing Entry already verified at this position.
            except IndexError as e:
                raise e
            #Missing Entries before this Entry.
            except GapError as e:
                raise e
            #Account has an invalid address.
            except AddressError as e:
                raise e
            #Invalid Ed25519 Public Key.
            except EdPublicKeyError as e:
                raise e
            #BLSError.
            except BLSError as e:
                doAssert(false, "Couldn't add a Send due to a BLSError, which can only be thrown when adding a Data: " & e.msg)

            echo "Successfully added the Data."

            #Create a Verification.
            try:
                asyncCheck verify(data)
            except Exception as e:
                doAssert(false, "Verify threw an Exception despite not naturally throwing anything: " & e.msg)
