include MainDatabase

proc mainVerifications() {.raises: [].} =
    {.gcsafe.}:
        verifications = newVerifications(functions.database)

        #Provide access to the verifier's height.
        functions.verifications.getVerifierHeight = proc (
            key: string
        ): int {.raises: [KeyError, LMDBError].} =
            verifications[key].height

        #Provide access to verifications.
        functions.verifications.getVerification = proc (
            key: string,
            nonce: int
        ): Verification {.raises: [KeyError, ValueError, BLSError, LMDBError, FinalAttributeError].} =
            verifications[key][nonce]

        #Provide access to the VerifierRecords of verifiers with unarchived Verifications.
        functions.verifications.getUnarchivedIndexes = proc (): seq[VerifierIndex] {.raises: [
            KeyError,
            ValueError,
            LMDBError,
            FinalAttributeError
        ].} =
            #Calculate who has new Verifications.
            result = @[]
            for verifier in verifications.verifiers():
                #Skip over Verifiers with no Verifications, if any manage to exist.
                if verifications[verifier].height == 0:
                    continue

                #Continue if this user doesn't have unarchived Verifications.
                if verifications[verifier].verifications.len == 0:
                    continue

                #Since there are unarchived verifications, add the VerifierIndex.
                var nonce: int = verifications[verifier].height - 1
                result.add(newVerifierIndex(
                    verifier,
                    nonce,
                    verifications[verifier].calculateMerkle(nonce)
                ))

        #Provide access to pending aggregate signatures.
        functions.verifications.getPendingAggregate = proc (
            verifierStr: string,
            nonce: int
        ): BLSSignature {.raises: [KeyError, ValueError, BLSError, LMDBError, FinalAttributeError].} =
            var
                #Grab the Verifier.
                verifier: Verifier = verifications[verifierStr]
                #Create a seq of signatures.
                sigs: seq[BLSSignature] = @[]
                #Start of the unarchived Verifications.
                start: int

            #If this Verifier has pending Verifications...
            if verifier.verifications.len > 0:
                start = verifier.verifications[0].nonce
            else:
                return nil

            #Iterate over every unarchived verification, up to and including the nonce.
            for verif in verifier{start .. nonce}:
                sigs.add(verif.signature)

            #Return the hash.
            return sigs.aggregate()

        #Used to calculate the aggregate with Verifications we just downloaded.
        functions.verifications.getPendingHashes = proc (
            key: string,
            nonceArg: int
        ): seq[string] {.raises: [KeyError, ValueError, BLSError, LMDBError, FinalAttributeError].} =
            result = @[]

            var
                #Grab the Verifier.
                verifier: Verifier = verifications[key]
                #Start of the unarchived Verifications.
                start: int
                #Nonce to end at.
                nonce: int = nonceArg

            #Make sure there are verifications.
            if verifications[key].height == 0:
                return

            #If this Verifier has pending Verifications...
            if verifier.verifications.len > 0:
                start = verifier.verifications[0].nonce
            else:
                return @[]

            #Make sure the nonce is within bounds.
            if verifications[key].height <= nonce:
                nonce = verifications[key].height - 1

            #Add the hashes.
            for verif in verifications[key][start .. nonce]:
                result.add(verif.hash.toString())

        #Handle Verifications.
        functions.verifications.addVerification = proc (
            verif: Verification
        ): bool {.raises: [ValueError, LMDBError].} =
            #Print that we're adding the Verification.
            echo "Adding a new Verification from a Block."

            #Set the result to a default value.
            result = true

            #Add the Verification to the Verifications.
            try:
                verifications.add(verif)
            except:
                #We either already got the Verification/got a competing Verification while handling the Block
                #OR
                #This had an unknown error.
                #We return false to be safe.
                return false

            #Add the Verification to the Lattice (discarded since we confirmed the Entry's existence).
            discard lattice.verify(merit, verif)

        #Handle Verifications.
        functions.verifications.addMemoryVerification = proc (
            verif: MemoryVerification
        ): bool {.raises: [ValueError, BLSError, LMDBError].} =
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
