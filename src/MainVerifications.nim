include MainDatabase

proc mainVerifications() {.forceCheck: [].} =
    {.gcsafe.}:
        verifications = newVerifications(functions.database)

        #Provide access to the verifier's height.
        functions.verifications.getVerifierHeight = proc (
            key: BLSPublicKey
        ): int {.forceCheck: [].} =
            verifications[key].height

        #Provide access to verifications.
        functions.verifications.getVerification = proc (
            key: BLSPublicKey,
            nonce: int
        ): Verification {.forceCheck: [
            IndexError
        ].} =
            try:
                result = verifications[key][nonce]
            except IndexError as e:
                fcRaise e

        #Provide access to the VerifierRecords of verifiers with unarchived Verifications.
        functions.verifications.getUnarchivedRecords = proc (): seq[VerifierRecord] {.forceCheck: [].} =
            #Check who has new Verifications.
            result = @[]
            for verifier in verifications.verifiers():
                #Skip over Verifiers with no Verifications, if any manage to exist.
                if verifications[verifier].height == 0:
                    continue

                #Continue if this user doesn't have unarchived Verifications.
                if verifications[verifier].verifications.len == 0:
                    continue

                #Since there are unarchived verifications, add the VerifierRecord.
                var
                    nonce: int = verifications[verifier].height - 1
                    merkle: Hash[384]
                try:
                    merkle = verifications[verifier].calculateMerkle(nonce)
                except IndexError as e:
                    doAssert(false, "Verifier.calculateMerkle() threw an IndexError when the index was verifier.height - 1: " & e.msg)

                result.add(newVerifierRecord(
                    verifier,
                    nonce,
                    merkle
                ))

        #Provide access to pending aggregate signatures.
        functions.verifications.getPendingAggregate = proc (
            key: BLSPublicKey,
            nonce: int
        ): BLSSignature {.forceCheck: [
            IndexError,
            BLSError
        ].} =
            var
                #Grab the Verifier.
                verifier: Verifier = verifications[key]
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
            try:
                for verif in verifier{start .. nonce}:
                    sigs.add(verif.signature)
            except IndexError as e:
                fcRaise e

            #Return the hash.
            try:
                return sigs.aggregate()
            except BLSError as e:
                fcRaise e

        #Used to calculate the aggregate with Verifications we just downloaded.
        functions.verifications.getPendingHashes = proc (
            key: BLSPublicKey,
            nonce: int
        ): seq[Hash[384]] {.forceCheck: [
            IndexError
        ].} =
            result = @[]

            var
                #Grab the Verifier.
                verifier: Verifier = verifications[key]
                #Start of the unarchived Verifications.
                start: int

            #Make sure there are verifications.
            if verifications[key].height == 0:
                return

            #If this Verifier has pending Verifications...
            if verifier.verifications.len > 0:
                start = verifier.verifications[0].nonce
            else:
                return @[]

            #Add the hashes.
            try:
                for verif in verifications[key][start .. nonce]:
                    result.add(verif.hash)
            except IndexError as e:
                fcRaise e

        #Handle Verifications.
        functions.verifications.addVerification = proc (
            verif: Verification
        ) {.forceCheck: [
            ValueError,
            IndexError
        ].} =
            #Print that we're adding the Verification.
            echo "Adding a new Verification from a Block."

            #Add the Verification to the Verifications DAG.
            try:
                verifications.add(verif)
            except IndexError as e:
                #Verification has already been added.
                fcRaise e
            except GapError:
                #Missing Verifications before this Verification.
                #Since we got this from a Block, we should've already synced all previous Verifications.
                doAssert(false, "Adding a Verification from a Block which we verified, despite not having all mentioned Verifications.")
            except MeritRemoval:
                #Verifier committed a malicious act against the network.
                discard

            #Add the Verification to the Lattice.
            try:
                lattice.verify(merit, verif)
            except ValueError as e:
                fcRaise e
            except IndexError as e:
                fcRaise e

            echo "Successfully added a new Verification."

        #Handle MemoryVerifications.
        functions.verifications.addMemoryVerification = proc (
            verif: MemoryVerification
        ) {.forceCheck: [
            ValueError,
            IndexError,
            GapError,
            BLSError
        ].} =
            #Print that we're adding the MemoryVerification.
            echo "Adding a new MemoryVerification."

            #Add the MemoryVerification to the Verifications DAG.
            try:
                verifications.add(verif)
            except IndexError as e:
                #Verification has already been added.
                fcRaise e
            except GapError as e:
                #Missing Verifications before this Verification.
                fcRaise e
            except BLSError as e:
                #Invalid BLS signature.
                fcRaise e
            except MeritRemoval:
                #Verifier committed a malicious act against the network.
                discard

            #Add the Verification to the Lattice.
            try:
                lattice.verify(merit, verif)
            except ValueError as e:
                fcRaise e
            except IndexError as e:
                fcRaise e

            echo "Successfully added a new MemoryVerification."
