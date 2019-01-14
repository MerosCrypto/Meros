include MainGlobals

proc mainVerifications() {.raises: [
    KeyError,
    ValueError,
    EmbIndexError,
    BLSError,
    FinalAttributeError
].} =
    {.gcsafe.}:
        verifications = newVerifications()

        #Provide access to the VerifierIndexes of verifiers with unarchived Verifications.
        events.on(
            "verifications.getUnarchivedIndexes",
            proc (): seq[VerifierIndex] {.raises: [KeyError, FinalAttributeError].} =
                #Calculate who has new Verifications.
                result = @[]
                for verifier in verifications.keys():
                    if verifications[verifier].archived != verifications[verifier].height:
                        var nonce: uint = verifications[verifier].height - 1
                        result.add(newVerifierIndex(
                            verifier,
                            nonce,
                            verifications[verifier].calculateMerkle(nonce)
                        ))
        )

        #Provide access to pending aggregate signatures.
        events.on(
            "verifications.getPendingAggregate",
            proc (
                verifierStr: string,
                nonce: uint
            ): BLSSignature {.raises: [KeyError, BLSError].} =
                var
                    #Grab the Verifier.
                    verifier: Verifier = verifications[verifierStr]
                    #Create a seq of signatures.
                    sigs: seq[BLSSignature] = @[]

                #Iterate over every unarchived verification, up to and including the nonce.
                for verif in verifier{verifier.archived .. nonce}:
                    sigs.add(verif.signature)

                #Return the hash.
                return sigs.aggregate()
        )

        #Handle Verifications.
        events.on(
            "verifications.memory_verification",
            proc (verif: MemoryVerification): bool {.raises: [ValueError, EmbIndexError, BLSError].} =
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
