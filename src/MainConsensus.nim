include MainDatabase

proc mainConsensus() {.forceCheck: [].} =
    {.gcsafe.}:
        consensus = newConsensus(database)

        #Provide access to the holder's height.
        functions.consensus.getHeight = proc (
            key: BLSPublicKey
        ): int {.forceCheck: [].} =
            if consensus.malicious.hasKey(key.toString()):
                return consensus[key].archived + 2
            result = consensus[key].height

        #Provide access to consensus.
        functions.consensus.getElement = proc (
            key: BLSPublicKey,
            nonce: int
        ): Element {.forceCheck: [
            IndexError
        ].} =
            if consensus.malicious.hasKey(key.toString()):
                if nonce == consensus[key].archived + 1:
                    try:
                        return consensus.malicious[key.toString()]
                    except KeyError as e:
                        doAssert(false, "Couldn't get a MeritRemoval despite confirming it exists: " & e.msg)
                elif nonce <= consensus[key].archived:
                    discard
                else:
                    raise newException(IndexError, "Element requested has been reverted.")

            try:
                result = consensus[key][nonce]
            except IndexError as e:
                fcRaise e

        #Provide access to the MeritHolderRecords of holders with unarchived Elements.
        functions.consensus.getUnarchivedRecords = proc (): tuple[
            records: seq[MeritHolderRecord],
            aggregate: BLSSignature
        ] {.forceCheck: [].} =
            #Signatures.
            var signatures: seq[BLSSignature] = @[]

            #Iterate over every holder.
            for holder in consensus.holders():
                #Continue if this user doesn't have unarchived Elements.
                if consensus[holder].archived == consensus[holder].height - 1:
                    continue

                #Since there are unarchived consensus, add the MeritHolderRecord.
                var
                    nonce: int = consensus[holder].height - 1
                    merkle: Hash[384]
                try:
                    merkle = consensus[holder].calculateMerkle(nonce)
                except IndexError as e:
                    doAssert(false, "MeritHolder.calculateMerkle() threw an IndexError when the index was holder.height - 1: " & e.msg)

                result.records.add(newMeritHolderRecord(
                    holder,
                    nonce,
                    merkle
                ))

                #Add all the pending signatures to signatures.
                try:
                    for e in consensus[holder].archived + 1 ..< consensus[holder].height:
                        signatures.add(consensus[holder].signatures[e])
                except KeyError as e:
                    doAssert(false, "Couldn't get a signature of a pending Element we know we have: " & e.msg)
                except IndexError as e:
                    doAssert(false, "Couldn't get an Element we know we have: " & e.msg)

            #Aggregate the Signatures.
            try:
                result.aggregate = signatures.aggregate()
            except BLSError as e:
                doAssert(false, "Failed to aggregate the signatures: " & e.msg)

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
            if holder.archived != holder.height - 1:
                start = holder.archived + 1
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
        ) {.forceCheck: [].} =
            #Print that we're adding the Verification.
            echo "Adding a new Verification from a Block."

            #See if the Transaction exists.
            var txExists: bool
            try:
                discard transactions[verif.hash]
                txExists = true
            except IndexError:
                txExists = false

            #Add the Verification to the Elements DAG.
            try:
                consensus.add(verif, txExists)
            #Missing Elements before this Verification.
            #Since we got this from a Block, we should've already synced all previous Elements.
            except GapError:
                doAssert(false, "Adding a Verification from a Block which we verified, despite not having all mentioned Elements.")

            echo "Successfully added a new Verification."

            if txExists and (not consensus.malicious.hasKey(verif.holder.toString())):
                #Add the Verification to the Transactions.
                try:
                    transactions.verify(verif, merit.state[verif.holder], merit.state.live)
                except ValueError:
                    return

        #Handle SignedElements.
        functions.consensus.addSignedVerification = proc (
            verif: SignedVerification
        ) {.forceCheck: [
            ValueError,
            GapError,
            DataExists
        ].} =
            #Print that we're adding the SignedVerification.
            echo "Adding a new SignedVerification."

            #See if the Transaction exists.
            var txExists: bool
            try:
                discard transactions[verif.hash]
                txExists = true
            except IndexError:
                txExists = false

            #Add the SignedVerification to the Elements DAG.
            try:
                consensus.add(verif, txExists)
            #Invalid signature.
            except ValueError as e:
                fcRaise e
            #Missing Elements before this Verification.
            except GapError as e:
                fcRaise e
            #Memory Verification was already added.
            except DataExists as e:
                fcRaise e
            #MeritHolder committed a malicious act against the network.
            except MaliciousMeritHolder as e:
                consensus.flag(cast[SignedMeritRemoval](e.removal))
                functions.network.broadcast(
                    MessageType.SignedMeritRemoval,
                    cast[SignedMeritRemoval](e.removal).signedSerialize()
                )
                return

            echo "Successfully added a new SignedVerification."

            if txExists and (not consensus.malicious.hasKey(verif.holder.toString())):
                #Add the Verification to the Transactions.
                try:
                    transactions.verify(verif, merit.state[verif.holder], merit.state.live)
                except ValueError:
                    return

            #Broadcast the SignedVerification.
            functions.network.broadcast(
                MessageType.SignedVerification,
                verif.signedSerialize()
            )

        functions.consensus.addMeritRemoval = proc (
            mr: MeritRemoval
        ) {.forceCheck: [
            ValueError
        ].} =
            #Print that we're adding the MeritRemoval.
            echo "Adding a new Merit Removal from a Block."

            #Add the MeritRemoval.
            try:
                consensus.add(mr)
            except ValueError as e:
                fcRaise e

            echo "Successfully added a new MeritRemoval."

        functions.consensus.addSignedMeritRemoval = proc (
            mr: SignedMeritRemoval
        ) {.forceCheck: [].} =
            discard
