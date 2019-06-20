include MainDatabase

proc mainConsensus() {.forceCheck: [].} =
    {.gcsafe.}:
        consensus = newConsensus(database)

        #Provide access to the holder's height.
        functions.consensus.getMeritHolderHeight = proc (
            key: BLSPublicKey
        ): int {.inline, forceCheck: [].} =
            consensus[key].height

        #Provide access to consensus.
        functions.consensus.getElement = proc (
            key: BLSPublicKey,
            nonce: int
        ): Element {.forceCheck: [
            IndexError
        ].} =
            try:
                result = consensus[key][nonce]
            except IndexError as e:
                fcRaise e

        #Provide access to the MeritHolderRecords of holders with unarchived Elements.
        functions.consensus.getUnarchivedRecords = proc (): seq[MeritHolderRecord] {.forceCheck: [].} =
            #Check who has new Elements.
            result = @[]
            for holder in consensus.holders():
                #Skip over MeritHolders with no Elements, if any manage to exist.
                if consensus[holder].height == 0:
                    continue

                #Continue if this user doesn't have unarchived Elements.
                if consensus[holder].elements.len == 0:
                    continue

                #Since there are unarchived consensus, add the MeritHolderRecord.
                var
                    nonce: int = consensus[holder].height - 1
                    merkle: Hash[384]
                try:
                    merkle = consensus[holder].calculateMerkle(nonce)
                except IndexError as e:
                    doAssert(false, "MeritHolder.calculateMerkle() threw an IndexError when the index was holder.height - 1: " & e.msg)

                result.add(newMeritHolderRecord(
                    holder,
                    nonce,
                    merkle
                ))

        #Provide access to pending aggregate signatures.
        functions.consensus.getPendingAggregate = proc (
            key: BLSPublicKey,
            nonce: int
        ): BLSSignature {.forceCheck: [
            IndexError,
            BLSError
        ].} =
            var
                #Grab the MeritHolder.
                holder: MeritHolder = consensus[key]
                #Create a seq of signatures.
                sigs: seq[BLSSignature] = @[]
                #Start of the unarchived Elements.
                start: int

            #If this MeritHolder has pending Elements...
            if holder.elements.len > 0:
                start = holder.elements[0].nonce
            else:
                return nil

            #Iterate over every unarchived Element, up to and including the nonce.
            try:
                var elems: seq[Element] = holder{start .. nonce}
                for elem in elems:
                    if elem of Verification:
                        sigs.add(cast[SignedVerification](elem).signature)
            except IndexError as e:
                fcRaise e

            #Return the aggregate.
            try:
                return sigs.aggregate()
            except BLSError as e:
                fcRaise e

        #Used to calculate the aggregate with Elements we just downloaded.
        functions.consensus.getPendingHashes = proc (
            key: BLSPublicKey,
            nonce: int
        ): seq[Hash[384]] {.forceCheck: [
            IndexError
        ].} =
            result = @[]

            var
                #Grab the MeritHolder.
                holder: MeritHolder = consensus[key]
                #Start of the unarchived Elements.
                start: int

            #Make sure there are consensus.
            if consensus[key].height == 0:
                return

            #If this MeritHolder has pending Elements...
            if holder.elements.len > 0:
                start = holder.elements[0].nonce
            else:
                return @[]

            #Add the hashes.
            try:
                for elem in consensus[key][start .. nonce]:
                    if elem of Verification:
                        result.add(cast[Verification](elem).hash)
            except IndexError as e:
                fcRaise e

        #Handle Elements.
        functions.consensus.addVerification = proc (
            verif: Verification
        ) {.forceCheck: [
            ValueError,
            DataExists
        ].} =
            #Print that we're adding the Verification.
            echo "Adding a new Verification from a Block."

            #Verify the MeritHolder has Merit.
            if merit.state[verif.holder] == 0:
                raise newException(ValueError, "MeritHolder doesn't hold any Merit.")

            #Add the Verification to the Elements DAG.
            try:
                consensus.add(verif)
            #Missing Elements before this Verification.
            #Since we got this from a Block, we should've already synced all previous Elements.
            except GapError:
                doAssert(false, "Adding a Verification from a Block which we verified, despite not having all mentioned Elements.")
            #Verification was already added.
            except DataExists as e:
                fcRaise e
            #MeritHolder committed a malicious act against the network.
            except MeritRemoval:
                discard

            echo "Successfully added a new Verification."

        #Handle SignedElements.
        functions.consensus.addSignedVerification = proc (
            verif: SignedVerification
        ) {.forceCheck: [
            ValueError,
            GapError,
            BLSError,
            DataExists
        ].} =
            #Print that we're adding the SignedVerification.
            echo "Adding a new SignedVerification."

            #Verify the MeritHolder has Merit.
            if merit.state[verif.holder] == 0:
                raise newException(ValueError, "MeritHolder doesn't hold any Merit.")

            #Add the SignedVerification to the Elements DAG.
            try:
                consensus.add(verif)
            #Invalid signature.
            except ValueError as e:
                fcRaise e
            #Missing Elements before this Verification.
            except GapError as e:
                fcRaise e
            #BLS Error.
            except BLSError as e:
                fcRaise e
            #Memory Verification was already added.
            except DataExists as e:
                fcRaise e
            #MeritHolder committed a malicious act against the network.
            except MeritRemoval:
                discard

            echo "Successfully added a new SignedVerification."

            #Broadcast the SignedVerification.
            functions.network.broadcast(
                MessageType.SignedVerification,
                verif.signedSerialize()
            )
