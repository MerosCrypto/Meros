include MainGlobals

proc mainVerifications*() {.raises: [].} =
    verifications = newVerifications()

    #Handle Verifications.
    events.on(
        "verifications.verification",
        proc (verif: MemoryVerification): bool {.raises: [ValueError, BLSError].} =
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
