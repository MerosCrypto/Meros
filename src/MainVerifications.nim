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

        #Provide access to the verifier's height.
        events.on(
            "verifications.getVerifierHeight",
            proc (key: string): uint {.raises: [KeyError].} =
                verifications[key].height
        )

        #Provide access to verifications.
        events.on(
            "verifications.getVerification",
            proc (key: string, nonce: uint): Verification {.raises: [KeyError].} =
                verifications[key][nonce]
        )

        #Provide access to the VerifierIndexes of verifiers with unarchived Verifications.
        events.on(
            "verifications.getUnarchivedIndexes",
            proc (): seq[VerifierIndex] {.raises: [KeyError, FinalAttributeError].} =
                #Calculate who has new Verifications.
                result = @[]
                for verifier in verifications.keys():
                    #Generally, we'd only need to see if the height is greater than the archived.
                    #That said, archived is supposed to start at -1. It can't as an uint.
                    #To solve this, we need to have an override here.

                    #Both of the following conditions must be met for this Verifier to be fully archived.
                    # 1) Their height - 1 == their archived
                    # (which only fails when their height is 1 but their archived is 0).
                    # 2) Their height is 1 and their first verification was archived.
                    if (
                        (verifications[verifier].archived == verifications[verifier].height - 1) and
                        (
                            (verifications[verifier].height == 1) and
                            (verifications[verifier][0].archived != 0)
                        )
                    ):
                        continue

                    #Since there are unarchived verifications, add the VerifierIndex.
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

        #Used to calculate the aggregate with Verifications we just downloaded.
        events.on(
            "verifications.getPendingHashes",
            proc (
                key: string,
                nonceArg: uint
            ): seq[string] {.raises: [KeyError].} =
                result = @[]

                #Make sure there are verifications.
                if verifications[key].height == 0:
                    return

                #Make sure the nonce is within bounds.
                var nonce: uint = nonceArg
                if verifications[key].height <= nonce:
                    nonce = verifications[key].height - 1

                #Add the hashes.
                for verif in verifications[key][verifications[key].archived .. nonce]:
                    result.add(verif.hash.toString())
        )

        #Handle Verifications.
        events.on(
            "verifications.verification",
            proc (verif: Verification) {.raises: [ValueError, EmbIndexError].} =
                #Print that we're adding the Verification.
                echo "Adding a new Verification from a Block."

                #Add the Verification to the Verifications.
                verifications.add(verif)

                #Add the Verification to the Lattice (discarded since we confirmed the Entry's existence).
                discard lattice.verify(merit, verif)
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
