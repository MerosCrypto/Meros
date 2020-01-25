include MainMerit

proc syncMeritRemovalTransactions(
    removal: MeritRemoval
): Future[void] {.forceCheck: [
    ValueError
], async.} =
    #Sync the MeritRemoval's transactions, if we don't have them already.
    proc syncMeritRemovalTransaction(
        hash: Hash[256]
    ): Future[void] {.forceCheck: [
        ValueError
    ], async.} =
        try:
            discard functions.transactions.getTransaction(hash)
        except IndexError:
            try:
                consensus.addMeritRemovalTransaction(await network.requestTransaction(hash))
            except DataMissing:
                raise newException(ValueError, "Couldn't find the Transaction behind a MeritRemoval.")
            except Exception as e:
                doAssert(false, "Syncing a MeritRemoval's Transaction threw an Exception despite catching all thrown Exceptions: " & e.msg)

    try:
        case removal.element1:
            of Verification as verif:
                await syncMeritRemovalTransaction(verif.hash)
            of VerificationPacket as packet:
                await syncMeritRemovalTransaction(packet.hash)
            else:
                discard

        case removal.element2:
            of Verification as verif:
                await syncMeritRemovalTransaction(verif.hash)
            of VerificationPacket as packet:
                await syncMeritRemovalTransaction(packet.hash)
            else:
                discard
    except ValueError as e:
        raise e
    except Exception as e:
        doAssert(false, "Syncing a MeritRemoval's Transactions threw an Exception despite catching all thrown Exceptions: " & e.msg)

proc mainConsensus() {.forceCheck: [].} =
    {.gcsafe.}:
        try:
            consensus = newConsensus(
                functions,
                database,
                merit.state,
                params.SEND_DIFFICULTY.toHash(256),
                params.DATA_DIFFICULTY.toHash(256)
            )
        except ValueError:
            doAssert(false, "Invalid initial Send/Data difficulty.")

        functions.consensus.getSendDifficulty = proc (): Hash[256] {.inline, forceCheck: [].} =
            consensus.filters.send.difficulty
        functions.consensus.getDataDifficulty = proc (): Hash[256] {.inline, forceCheck: [].} =
            consensus.filters.data.difficulty

        #Provide access to if a holder is malicious.
        functions.consensus.isMalicious = proc (
            nick: uint16
        ): bool {.inline, forceCheck: [].} =
            consensus.malicious.hasKey(nick)

        #Provides access to a holder's nonce.
        functions.consensus.getArchivedNonce = proc (
            holder: uint16
        ): int {.inline, forceCheck: [].} =
            consensus.getArchivedNonce(holder)

        #Get if a hash has an archived packet or not.
        #Any hash with holder(s) that isn't unmentioned has an archived packet.
        functions.consensus.hasArchivedPacket = proc (
            hash: Hash[256]
        ): bool {.forceCheck: [
            IndexError
        ].} =
            var status: TransactionStatus
            try:
                status = consensus.getStatus(hash)
            except IndexError as e:
                fcRaise e

            return (status.holders.len != 0) and (not consensus.unmentioned.contains(hash))

        #Get a Transaction's status.
        functions.consensus.getStatus = proc (
            hash: Hash[256]
        ): TransactionStatus {.forceCheck: [
            IndexError
        ].} =
            try:
                result = consensus.getStatus(hash)
            except IndexError:
                raise newException(IndexError, "Couldn't find a Status for that hash.")

        functions.consensus.getThreshold = proc (
            epoch: int
        ): int {.inline, forceCheck: [].} =
            merit.state.nodeThresholdAt(epoch)

        functions.consensus.getPending = proc (): tuple[
            packets: seq[VerificationPacket],
            elements: seq[BlockElement],
            aggregate: BLSSignature
        ] {.forceCheck: [].} =
            var pending: tuple[
                packets: seq[SignedVerificationPacket],
                elements: seq[BlockElement],
                aggregate: BLSSignature
            ] = consensus.getPending()

            result = (cast[seq[VerificationPacket]](pending.packets), pending.elements, pending.aggregate)

        #Handle SignedVerifications.
        functions.consensus.addSignedVerification = proc (
            verif: SignedVerification
        ) {.forceCheck: [
            ValueError,
            DataExists
        ].} =
            #Print that we're adding the SignedVerification.
            echo "Adding a new Signed Verification."

            #Add the SignedVerification to the Consensus DAG.
            var mr: bool
            try:
                consensus.add(merit.state, verif)
            #Invalid signature.
            except ValueError as e:
                raise e
            #Already added.
            except DataExists as e:
                raise e
            #MeritHolder committed a malicious act against the network.
            except MaliciousMeritHolder as e:
                #Flag the MeritRemoval.
                consensus.flag(merit.blockchain, merit.state, cast[SignedMeritRemoval](e.removal))

                #Set mr to true.
                mr = true

            if mr:
                try:
                    #Broadcast the first MeritRemoval.
                    functions.network.broadcast(
                        MessageType.SignedMeritRemoval,
                        cast[SignedMeritRemoval](consensus.malicious[verif.holder][0]).signedSerialize()
                    )
                except KeyError as e:
                    doAssert(false, "Couldn't get the MeritRemoval of someone who just had one created: " & e.msg)
                return

            echo "Successfully added a new Signed Verification."

            #Broadcast the SignedVerification.
            functions.network.broadcast(
                MessageType.SignedVerification,
                verif.signedSerialize()
            )

        #Handle VerificationPackets.
        functions.consensus.addVerificationPacket = proc (
            packet: VerificationPacket
        ) {.forceCheck: [].} =
            #Print that we're adding the VerificationPacket.
            echo "Adding a new Verification Packet from a Block."

            #Add the Verification to the Consensus DAG.
            consensus.add(merit.state, packet)

            echo "Successfully added a new Verification Packet."

        #Handle SendDifficulties.
        functions.consensus.addSendDifficulty = proc (
            sendDiff: SendDifficulty
        ) {.forceCheck: [].} =
            #Print that we're adding the SendDifficulty.
            echo "Adding a new Send Difficulty from a Block."

            #Add the SendDifficulty to the Consensus DAG.
            consensus.add(merit.state, sendDiff)

            echo "Successfully added a new Send Difficulty."

        #Handle SignedSendDifficulties.
        functions.consensus.addSignedSendDifficulty = proc (
            sendDiff: SignedSendDifficulty
        ) {.forceCheck: [
            ValueError,
            DataExists
        ].} =
            #Print that we're adding the SendDifficulty.
            echo "Adding a new Send Difficulty."

            #Add the SendDifficulty.
            var mr: bool
            try:
                consensus.add(merit.state, sendDiff)
            except ValueError as e:
                raise e
            except DataExists as e:
                raise e
            except MaliciousMeritHolder as e:
                #Flag the MeritRemoval.
                consensus.flag(merit.blockchain, merit.state, cast[SignedMeritRemoval](e.removal))

                #Set mr to true.
                mr = true

            if mr:
                try:
                    #Broadcast the first MeritRemoval.
                    functions.network.broadcast(
                        MessageType.SignedMeritRemoval,
                        cast[SignedMeritRemoval](consensus.malicious[sendDiff.holder][0]).signedSerialize()
                    )
                except KeyError as e:
                    doAssert(false, "Couldn't get the MeritRemoval of someone who just had one created: " & e.msg)
                return

            echo "Successfully added a new Signed Send Difficulty."

            #Broadcast the SendDifficulty.
            functions.network.broadcast(
                MessageType.SignedSendDifficulty,
                sendDiff.signedSerialize()
            )

        #Handle DataDifficulties.
        functions.consensus.addDataDifficulty = proc (
            dataDiff: DataDifficulty
        ) {.forceCheck: [].} =
            #Print that we're adding the DataDifficulty.
            echo "Adding a new Data Difficulty from a Block."

            #Add the DataDifficulty to the Consensus DAG.
            consensus.add(merit.state, dataDiff)

            echo "Successfully added a new Data Difficulty."

        #Handle SignedDataDifficulties.
        functions.consensus.addSignedDataDifficulty = proc (
            dataDiff: SignedDataDifficulty
        ) {.forceCheck: [
            ValueError,
            DataExists
        ].} =
            #Print that we're adding the DataDifficulty.
            echo "Adding a new Data Difficulty."

            #Add the DataDifficulty.
            var mr: bool = false
            try:
                consensus.add(merit.state, dataDiff)
            except ValueError as e:
                raise e
            except DataExists as e:
                raise e
            except MaliciousMeritHolder as e:
                #Flag the MeritRemoval.
                consensus.flag(merit.blockchain, merit.state, cast[SignedMeritRemoval](e.removal))

                #Set mr to true.
                mr = true

            if mr:
                try:
                    #Broadcast the first MeritRemoval.
                    functions.network.broadcast(
                        MessageType.SignedMeritRemoval,
                        cast[SignedMeritRemoval](consensus.malicious[dataDiff.holder][0]).signedSerialize()
                    )
                except KeyError as e:
                    doAssert(false, "Couldn't get the MeritRemoval of someone who just had one created: " & e.msg)
                return

            echo "Successfully added a new Signed Data Difficulty."

            #Broadcast the DataDifficulty.
            functions.network.broadcast(
                MessageType.SignedDataDifficulty,
                dataDiff.signedSerialize()
            )

        #Verify an unsigned MeritRemoval.
        functions.consensus.verifyUnsignedMeritRemoval = proc (
            mr: MeritRemoval
        ): Future[void] {.forceCheck: [
            ValueError,
            DataExists
        ], async.} =
            try:
                await syncMeritRemovalTransactions(mr)
            except ValueError as e:
                raise e
            except Exception as e:
                doAssert(false, "Syncing a MeritRemoval's Transactions threw an Exception despite catching all thrown Exceptions: " & e.msg)

            try:
                consensus.verify(mr)
            except ValueError as e:
                raise e
            except DataExists as e:
                #If it's cached, it's already been verified and it's not archived yet.
                if not consensus.malicious.hasKey(mr.holder):
                    raise e

                try:
                    for cachedMR in consensus.malicious[mr.holder]:
                        if cast[Element](mr) == cast[Element](cachedMR):
                            return
                except KeyError:
                    doAssert(false, "Merit Holder confirmed to be in malicious doesn't have an entry in malicious.")
                raise e

        #Handle SignedMeritRemovals.
        functions.consensus.addSignedMeritRemoval = proc (
            mr: SignedMeritRemoval
        ): Future[void] {.forceCheck: [
            ValueError,
            DataExists
        ], async.} =
            #Print that we're adding the MeritRemoval.
            echo "Adding a new Merit Removal."

            try:
                await syncMeritRemovalTransactions(mr)
            except ValueError as e:
                raise e
            except Exception as e:
                doAssert(false, "Syncing a MeritRemoval's Transactions threw an Exception despite catching all thrown Exceptions: " & e.msg)

            while true:
                if tryAcquire(smrLock):
                    break

                try:
                    await sleepAsync(10)
                except Exception as e:
                    doAssert(false, "Failed to complete an async sleep: " & e.msg)

            #Add the MeritRemoval.
            try:
                consensus.add(merit.blockchain, merit.state, mr)
            except ValueError as e:
                raise e
            except DataExists as e:
                raise e
            finally:
                release(smrLock)

            echo "Successfully added a new Signed Merit Removal."

            #Broadcast the first MeritRemoval.
            try:
                functions.network.broadcast(
                    MessageType.SignedMeritRemoval,
                    cast[SignedMeritRemoval](consensus.malicious[mr.holder][0]).signedSerialize()
                )
            except KeyError as e:
                doAssert(false, "Couldn't get the MeritRemoval of someone who just had one created: " & e.msg)
