include MainDatabase

#Revert a MeritHolder's pending actions.
proc revertPending(
    removal: MeritRemoval,
    consensus: Consensus,
    transactions: var Transactions,
    state: var State
) {.forceCheck: [].} =
    #Only revert pending actions if this was the first MeritRemoval.
    try:
        if consensus.malicious[removal.holder.toString()].len != 1:
            return
    except KeyError as e:
        doAssert(false, "Couldn't get the MeritRemovals of someone who we're trying to revert the pending actions of: " & e.msg)

    #Revert pending actions.
    var holder: MeritHolder = consensus[removal.holder]
    for e in holder.archived + 1 ..< holder.height:
        var elem: Element
        try:
            elem = holder[e]
        except IndexError as e:
            doAssert(false, "Couldn't get a known pending Element: " & e.msg)

        case elem:
            of Verification as verif:
                #This has the risk to subtract less/more from the weight than was added.
                #There is no underflow risk, and if the MeritHolder's weight went up, this has positive effects.
                #If their weight went down, this has negative effects.
                #The threshold used to be +601 to cover State changes. It is now +1201.
                try:
                    transactions.unverify(verif, state[verif.holder], state.live)
                except ValueError:
                    #If it's out of Epochs, move on.
                    discard
            else:
                doAssert(false, "Unsupported Element type.")

#Reapply reverted pending actions.
proc reapplyPending(
    record: MeritHolderRecord,
    consensus: Consensus,
    transactions: var Transactions,
    state: var State
) {.forceCheck: [].} =
    var holder: MeritHolder = consensus[record.key]
    for e in holder.archived + 1 .. record.nonce:
        var elem: Element
        try:
            elem = holder[e]
        except IndexError as e:
            doAssert(false, "Couldn't get a known pending Element: " & e.msg)

        case elem:
            of Verification as verif:
                #This reapplies the Verification as if we received it before the Block that triggered this.
                try:
                    transactions.verify(verif, state[verif.holder], state.live)
                except ValueError:
                    #If it's out of Epochs, move on.
                    discard
            else:
                doAssert(false, "Unsupported Element type.")

proc mainConsensus() {.forceCheck: [].} =
    {.gcsafe.}:
        consensus = newConsensus(database)

        #Provide access to if a holder is malicious.
        functions.consensus.isMalicious = proc (
            key: BLSPublicKey
        ): bool {.inline, forceCheck: [].} =
            consensus.malicious.hasKey(key.toString())

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
                        return consensus.malicious[key.toString()][0]
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

        #Handle Elements.
        functions.consensus.addVerification = proc (
            verif: Verification
        ) {.forceCheck: [
            ValueError
        ].} =
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
            except ValueError as e:
                fcRaise e
            #Since we got this from a Block, we should've already synced all previous Elements.
            except GapError:
                doAssert(false, "Adding a Verification from a Block which we verified, despite not having all mentioned Elements.")
            except DataExists as e:
                doAssert(false, "Tried to add an unsigned Element we already have: " & e.msg)

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
            echo "Adding a new Signed Verification."

            #Check if this is cause for a MaliciousMeritRemoval.
            try:
                consensus.checkMalicious(verif)
            except GapError as e:
                fcRaise e
            #Already added.
            except DataExists as e:
                fcRaise e
            #MeritHolder committed a malicious act against the network.
            except MaliciousMeritHolder as e:
                #Flag the MeritRemoval.
                consensus.flag(cast[SignedMeritRemoval](e.removal))
                #Revert pending actions.
                e.removal.revertPending(consensus, transactions, merit.state)

                try:
                    #Broadcast the first MeritRemoval.
                    functions.network.broadcast(
                        MessageType.SignedMeritRemoval,
                        cast[SignedMeritRemoval](consensus.malicious[verif.holder.toString()][0]).signedSerialize()
                    )
                except KeyError as e:
                    doAssert(false, "Couldn't get the MeritRemoval of someone who just had one created: " & e.msg)
                return

            #See if the Transaction exists.
            try:
                discard transactions[verif.hash]
            except IndexError:
                raise newException(ValueError, "Unknown Verification.")

            #Add the SignedVerification to the Elements DAG.
            try:
                consensus.add(verif)
            #Invalid signature.
            except ValueError as e:
                fcRaise e
            #Missing Elements before this Verification.
            except GapError as e:
                fcRaise e

            echo "Successfully added a new Signed Verification."

            if not consensus.malicious.hasKey(verif.holder.toString()):
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

            echo "Successfully added a new Merit Removal."

        functions.consensus.addSignedMeritRemoval = proc (
            mr: SignedMeritRemoval
        ) {.forceCheck: [
            ValueError
        ].} =
            #Print that we're adding the MeritRemoval.
            echo "Adding a new Merit Removal."

            #Add the MeritRemoval.
            try:
                consensus.add(mr)
            except ValueError as e:
                fcRaise e

            #Revert pending actions.
            mr.revertPending(consensus, transactions, merit.state)

            echo "Successfully added a new Signed Merit Removal."

            #Broadcast the first MeritRemoval.
            try:
                functions.network.broadcast(
                    MessageType.SignedMeritRemoval,
                    cast[SignedMeritRemoval](consensus.malicious[mr.holder.toString()][0]).signedSerialize()
                )
            except KeyError as e:
                doAssert(false, "Couldn't get the MeritRemoval of someone who just had one created: " & e.msg)
