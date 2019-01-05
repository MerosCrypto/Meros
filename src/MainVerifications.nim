include MainGlobals

proc mainVerifications*() {.raises: [].} =
    verifications = newVerifications()

    #Handle Verifications.
    events.on(
        "verifications.memory_verification",
        proc (verif: MemoryVerification): bool {.raises: [ValueError, BLSError].} =
            #Print that we're adding the Verification.
            echo "Adding a new Verification."

            #Verify the signature.
            verif.signature.setAggregationInfo(
                newBLSAggregationInfo(verif.verifier, verif.hash.toString())
            )
            if not verif.signature.verify():
                echo "Failed to add the Verification."
                return false

            #Add the Verification to the Verifications.
            verifications.add(verif)

            #Add the Verification to the Lattice.
            result = lattice.verify(merit, verif)
            if not result:
                echo "Missing whatever we just added a Verification for."
    )
