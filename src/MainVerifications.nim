include MainGlobals

proc mainVerifications() {.raises: [].} =
    {.gcsafe.}:
        verifications = newVerifications()

        #Provide access to the verifier's height.
        functions.verifications.getVerifierHeight = proc (
            key: string
        ): uint {.raises: [KeyError].} =
            verifications[key].height

        #Provide access to verifications.
        functions.verifications.getVerification = proc (
            key: string,
            nonce: uint
        ): Verification {.raises: [KeyError].} =
            verifications[key][nonce]

        #Provide access to the VerifierIndexes of verifiers with unarchived Verifications.
        functions.verifications.getUnarchivedIndexes = proc (): seq[VerifierIndex] {.raises: [
            KeyError,
            FinalAttributeError
        ].} =
            #Calculate who has new Verifications.
            result = @[]
            for verifier in verifications.keys():
                #Skip over verifier's with no Verifications, if any manage to exist.
                if verifications[verifier].height == 0:
                    continue

                #Generally, we'd only need to see if the height is greater than the archived.
                #That said, archived is supposed to start at -1. It can't as an uint.
                #To solve this, we have a different check.
                #We check if the tip Verification was archived or not.
                if verifications[verifier][^1].archived != 0:
                    continue

                #Since there are unarchived verifications, add the VerifierIndex.
                var nonce: uint = verifications[verifier].height - 1
                result.add(newVerifierIndex(
                    verifier,
                    nonce,
                    verifications[verifier].calculateMerkle(nonce)
                ))

        #Provide access to pending aggregate signatures.
        functions.verifications.getPendingAggregate = proc (
            verifierStr: string,
            nonce: uint
        ): BLSSignature {.raises: [KeyError, BLSError].} =
            var
                #Grab the Verifier.
                verifier: Verifier = verifications[verifierStr]
                #Create a seq of signatures.
                sigs: seq[BLSSignature] = @[]
                #Start of the unarchived Verifications.
                start: uint = verifier.archived + 1

            #Override to handle how archived is 0 twice.
            if start == 1:
                if verifier[0].archived == 0:
                    start = 0

            #Iterate over every unarchived verification, up to and including the nonce.
            for verif in verifier{start .. nonce}:
                sigs.add(verif.signature)

            #Return the hash.
            return sigs.aggregate()

        #Used to calculate the aggregate with Verifications we just downloaded.
        functions.verifications.getPendingHashes = proc (
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

        #Handle Verifications.
        functions.verifications.addVerification = proc (
            verif: Verification
        ): bool {.raises: [ValueError].} =
            #Print that we're adding the Verification.
            echo "Adding a new Verification from a Block."

            #Set the result to a default value.
            result = true

            #Add the Verification to the Verifications.
            try:
                verifications.add(verif)
            except:
                #We either got the Verification/a competing Verification while handling the Block
                #OR
                #This had an unknown error.
                #We return false to be safe.
                return false

            #Add the Verification to the Lattice (discarded since we confirmed the Entry's existence).
            discard lattice.verify(merit, verif)

        #Handle Verifications.
        functions.verifications.addMemoryVerification = proc (
            verif: MemoryVerification
        ): bool {.raises: [ValueError, BLSError].} =
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
            try:
                verifications.add(verif)
            except:
                return false

            #Add the Verification to the Lattice.
            result = lattice.verify(merit, verif)
            if not result:
                echo "Missing whatever we just added a Verification for."
