#Errors.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#GlobalFunctionBox object.
import ../../objects/GlobalFunctionBoxObj

#Consensus DB lib.
import ../Filesystem/DB/ConsensusDB

#Transaction lib.
import ../Transactions/Transaction

#Block, Blockchain and Epoch objects.
import ../Merit/objects/BlockObj
import ../Merit/objects/BlockchainObj
import ../Merit/objects/EpochsObj

#State lib.
import ../Merit/State

#SpamFilter object.
import objects/SpamFilterObj
export SpamFilterObj

#Element libs.
import Elements/Elements
export Elements

#TransactionStatus lib.
import TransactionStatus
export TransactionStatus

#Consensus object.
import objects/ConsensusObj
export ConsensusObj

#Serialize libs.
import ../../Network/Serialize/Consensus/SerializeElement
import ../../Network/Serialize/Consensus/SerializeVerification
import ../../Network/Serialize/Consensus/SerializeSendDifficulty
import ../../Network/Serialize/Consensus/SerializeDataDifficulty

#Sets standard lib.
import sets

#Tables standard lib.
import tables

#Constructor wrapper.
proc newConsensus*(
    functions: GlobalFunctionBox,
    db: DB,
    state: State,
    sendDiff: Hash[256],
    dataDiff: Hash[256]
): Consensus {.inline, forceCheck: [].} =
    newConsensusObj(functions, db, state, sendDiff, dataDiff)

#Verify a MeritRemoval's validity.
proc verify*(
    consensus: Consensus,
    mr: MeritRemoval
) {.forceCheck: [
    ValueError
].} =
    proc checkSecondCompeting(
        hash: Hash[256]
    ) {.forceCheck: [
        ValueError
    ].} =
        if mr.partial:
            var status: TransactionStatus
            try:
                status = consensus.db.load(hash)
            except DBReadError:
                raise newException(ValueError, "Unknown hash.")

            if (not status.holders.contains(mr.holder)) or status.signatures.hasKey(mr.holder):
                raise newException(ValueError, "Verification isn't archived.")

        doAssert(false, "Verified competing MeritRemovals aren't supported.")

    proc checkSecondSameNonce(
        nonce: int
    ) {.forceCheck: [
        ValueError
    ].} =
        try:
            if mr.partial and ((nonce > consensus.archived[mr.holder]) or (mr.element1 != consensus.db.load(mr.holder, nonce))):
                raise newException(ValueError, "First Element isn't archived.")
        except KeyError:
            raise newException(ValueError, "MeritRemoval has an invalid holder.")
        except DBReadError as e:
            doAssert(false, "Nonce was within bounds yet no Element could be loaded: " & e.msg)

        case mr.element2:
            of Verification as _:
                raise newException(ValueError, "Invalid second Element.")
            of VerificationPacket as _:
                raise newException(ValueError, "Invalid second Element.")
            of SendDifficulty as sd:
                if nonce != sd.nonce:
                    raise newException(ValueError, "Second Element has a distinct nonce.")
            of DataDifficulty as dd:
                if nonce != dd.nonce:
                    raise newException(ValueError, "Second Element has a distinct nonce.")
            else:
                doAssert(false, "Unsupported MeritRemoval Element.")

    try:
        case mr.element1:
            of Verification as verif:
                checkSecondCompeting(verif.hash)
            of VerificationPacket as packet:
                checkSecondCompeting(packet.hash)
            of SendDifficulty as sd:
                checkSecondSameNonce(sd.nonce)
            of DataDifficulty as dd:
                checkSecondSameNonce(dd.nonce)
            else:
                doAssert(false, "Unsupported MeritRemoval Element.")
    except ValueError as e:
        raise e

#Flag a MeritHolder as malicious.
proc flag*(
    consensus: Consensus,
    blockchain: Blockchain,
    state: State,
    removal: MeritRemoval
) {.forceCheck: [].} =
    #Make sure there's a seq.
    if not consensus.malicious.hasKey(removal.holder):
        consensus.malicious[removal.holder] = @[]

    #Add the MeritRemoval, if it's signed.
    if removal of SignedMeritRemoval:
        try:
            consensus.malicious[removal.holder].add(cast[SignedMeritRemoval](removal))
        except KeyError as e:
            doAssert(false, "Couldn't add a MeritRemoval to a seq we've confirmed exists: " & e.msg)

    #Reclaulcate the affected Transactions in Epochs.
    var
        status: TransactionStatus
        blockInEpochs: Block
    for b in max(blockchain.height - 5, 0) ..< blockchain.height:
        try:
            blockInEpochs = blockchain[b]
        except IndexError as e:
            doAssert(false, "Couldn't get a Block from the Blockchain despite iterating up to the height: " & e.msg)

        for packet in blockInEpochs.body.packets:
            try:
                status = consensus.getStatus(packet.hash)
            except IndexError as e:
                doAssert(false, "Couldn't get the status of a Transaction in Epochs: " & e.msg)

            if status.verified and status.holders.contains(removal.holder):
                var merit: int = 0
                for holder in status.holders:
                    if not consensus.malicious.hasKey(holder):
                        merit += state[holder]

                if merit < state.protocolThresholdAt(status.epoch):
                    consensus.unverify(state, packet.hash, status)

    #Recalculate the affected Transactions not yet in Epochs.
    for hash in consensus.unmentioned:
        try:
            status = consensus.getStatus(hash)
        except IndexError as e:
            doAssert(false, "Couldn't get the status of a Transaction yet to be mentioned in Epochs: " & e.msg)

        if status.verified and status.holders.contains(removal.holder):
            var merit: int = 0
            for holder in status.holders:
                if not consensus.malicious.hasKey(holder):
                    merit += state[holder]

            if merit < state.protocolThresholdAt(status.epoch):
                consensus.unverify(state, hash, status)

#Get a holder's nonce.
#Used to verify Blocks in NetworkSync.
proc getArchivedNonce*(
    consensus: Consensus,
    holder: uint16
): int {.inline, forceCheck: [].} =
    try:
        result = consensus.archived[holder]
    except KeyError:
        #This causes Blocks with invalid holders to get rejected for having an invalid nonce.
        #We shouldn't need it due to other checks, and this removes the neccessity to add try/catches to the entire chain.
        result = -2

#Register a Transaction.
proc register*(
    consensus: Consensus,
    state: State,
    tx: Transaction,
    height: int
) {.forceCheck: [].} =
    #Create the status.
    var status: TransactionStatus = newTransactionStatusObj(tx.hash, height + 7)

    for input in tx.inputs:
        #Check if this Transaction's parent was beaten.
        try:
            if (
                (not status.beaten) and
                (not (tx of Claim)) and
                (not ((tx of Data) and cast[Data](tx).isFirstData)) and
                (consensus.getStatus(input.hash).beaten)
            ):
                status.beaten = true
        except IndexError:
            doAssert(false, "Parent Transaction doesn't have a status.")

        #Check for competing Transactions.
        var spenders: seq[Hash[256]] = consensus.functions.transactions.getSpenders(input)
        if spenders.len != 1:
            status.competing = true

            #If there's a competing Transaction, mark competitors as needing to default.
            #This will run for every input with multiple spenders.
            if status.competing:
                for spender in spenders:
                    if spender == tx.hash:
                        continue

                    try:
                        consensus.getStatus(spender).competing = true
                    except IndexError:
                        doAssert(false, "Competing Transaction doesn't have a Status despite being marked as a spender.")

    #Set the status.
    consensus.setStatus(tx.hash, status)

    #Mark the Transaction as unmentioned.
    consensus.setUnmentioned(tx.hash)

#Add a VerificationPacket.
proc add*(
    consensus: Consensus,
    state: State,
    packet: VerificationPacket
) {.forceCheck: [].} =
    var status: TransactionStatus
    #Get the status.
    try:
        status = consensus.getStatus(packet.hash)
    #If there's no TX status, the TX wasn't registered.
    except IndexError:
        doAssert(false, "Adding a VerificationPacket for a non-existent Transaction.")

    #Add the packet.
    status.add(packet)
    #Calculate Merit.
    consensus.calculateMerit(state, packet.hash, status)
    #Set the status.
    consensus.setStatus(packet.hash, status)

#Add a SignedVerification.
proc add*(
    consensus: Consensus,
    state: State,
    verif: SignedVerification
) {.forceCheck: [
    ValueError,
    DataExists
].} =
    #Verify the holder exists.
    if verif.holder >= uint16(state.holders.len):
        raise newException(ValueError, "Invalid holder.")

    #Verify the signature.
    try:
        if not verif.signature.verify(
            newBLSAggregationInfo(
                state.holders[verif.holder],
                verif.serializeWithoutHolder()
            )
        ):
            raise newException(ValueError, "Invalid SignedVerification signature.")
    except BLSError:
        doAssert(false, "Holder with an infinite key entered the system.")

    #Get the status.
    var status: TransactionStatus
    try:
        status = consensus.getStatus(verif.hash)
    except IndexError:
        doAssert(false, "SignedVerification added for a Transaction which was not registered.")

    #Add the Verification.
    try:
        status.add(verif)
    except DataExists as e:
        raise e

    #Calculate Merit.
    consensus.calculateMerit(state, verif.hash, status)
    #Set the status.
    consensus.setStatus(verif.hash, status)

#Add a SendDifficulty.
proc add*(
    consensus: Consensus,
    state: State,
    sendDiff: SendDifficulty
) {.forceCheck: [].} =
    consensus.db.save(sendDiff)
    consensus.filters.send.update(sendDiff.holder, state[sendDiff.holder], sendDiff.difficulty)

#Add a SignedSendDifficulty.
proc add*(
    consensus: Consensus,
    state: State,
    sendDiff: SignedSendDifficulty
) {.forceCheck: [
    ValueError,
    DataExists,
    MaliciousMeritHolder
].} =
    #Verify the holder exists.
    if sendDiff.holder >= uint16(state.holders.len):
        raise newException(ValueError, "Invalid holder.")

    #Verify the SendDifficulty's signature.
    try:
        if not sendDiff.signature.verify(
            newBLSAggregationInfo(
                state.holders[sendDiff.holder],
                sendDiff.serializeWithoutHolder()
            )
        ):
            raise newException(ValueError, "Invalid SendDifficulty signature.")
    except BLSError:
        raise newException(ValueError, "Invalid SendDifficulty signature.")

    #Verify the nonce. This is done in NetworkSync for non-signed versions.
    if sendDiff.nonce != consensus.db.load(sendDiff.holder) + 1:
        if sendDiff.nonce <= consensus.db.load(sendDiff.holder):
            #If this isn't the existing Element, it's cause for a MeritRemoval.
            var other: BlockElement
            try:
                other = consensus.db.load(sendDiff.holder, sendDiff.nonce)
            except DBReadError as e:
                doAssert(false, "Couldn't read a Block Element with a nonce lower than the holder's current nonce: " & e.msg)

            if other == sendDiff:
                raise newException(DataExists, "Already added this SendDifficulty.")

            raise newMaliciousMeritHolder(
                "SendDifficulty shares a nonce with a different Element.",
                newSignedMeritRemoval(sendDiff.holder, true, other, sendDiff, sendDiff.signature, state.holders)
            )

        raise newException(ValueError, "SendDifficulty skips a nonce.")

    #Add the SendDifficulty.
    consensus.add(state, cast[SendDifficulty](sendDiff))

    #Save the signature.
    try:
        consensus.signatures[sendDiff.holder].add(sendDiff.signature)
        consensus.db.saveSignature(sendDiff.holder, sendDiff.nonce, sendDiff.signature)
    except KeyError as e:
        doAssert(false, "Couldn't cache a signature: " & e.msg)

#Add a DataDifficulty.
proc add*(
    consensus: Consensus,
    state: State,
    dataDiff: DataDifficulty
) {.forceCheck: [].} =
    consensus.db.save(dataDiff)
    consensus.filters.data.update(dataDiff.holder, state[dataDiff.holder], dataDiff.difficulty)

#Add a SignedDataDifficulty.
proc add*(
    consensus: Consensus,
    state: State,
    dataDiff: SignedDataDifficulty
) {.forceCheck: [
    ValueError,
    DataExists,
    MaliciousMeritHolder
].} =
    #Verify the holder exists.
    if dataDiff.holder >= uint16(state.holders.len):
        raise newException(ValueError, "Invalid holder.")

    #Verify the DataDifficulty's signature.
    try:
        if not dataDiff.signature.verify(
            newBLSAggregationInfo(
                state.holders[dataDiff.holder],
                dataDiff.serializeWithoutHolder()
            )
        ):
            raise newException(ValueError, "Invalid DataDifficulty signature.")
    except BLSError:
        raise newException(ValueError, "Invalid DataDifficulty signature.")

    #Verify the nonce. This is done in NetworkSync for non-signed versions.
    if dataDiff.nonce != consensus.db.load(dataDiff.holder) + 1:
        if dataDiff.nonce <= consensus.db.load(dataDiff.holder):
            #If this isn't the existing Element, it's cause for a MeritRemoval.
            var other: BlockElement
            try:
                other = consensus.db.load(dataDiff.holder, dataDiff.nonce)
            except DBReadError as e:
                doAssert(false, "Couldn't read a Block Element with a nonce lower than the holder's current nonce: " & e.msg)

            if other == dataDiff:
                raise newException(DataExists, "Already added this DataDifficulty.")

            raise newMaliciousMeritHolder(
                "DataDifficulty shares a nonce with a different Element.",
                newSignedMeritRemoval(dataDiff.holder, true, other, dataDiff, dataDiff.signature, state.holders)
            )

        raise newException(ValueError, "DataDifficulty skips a nonce.")

    #Add the DataDifficulty.
    consensus.add(state, cast[DataDifficulty](dataDiff))

    #Save the signature.
    try:
        consensus.signatures[dataDiff.holder].add(dataDiff.signature)
        consensus.db.saveSignature(dataDiff.holder, dataDiff.nonce, dataDiff.signature)
    except KeyError as e:
        doAssert(false, "Couldn't cache a signature: " & e.msg)

#Add a SignedMeritRemoval.
proc add*(
    consensus: Consensus,
    blockchain: Blockchain,
    state: State,
    mr: SignedMeritRemoval
) {.forceCheck: [
    ValueError
].} =
    #Verify the MeritRemoval's signature.
    if not mr.signature.verify(mr.agInfo(state.holders[mr.holder])):
        raise newException(ValueError, "Invalid MeritRemoval signature.")

    try:
        consensus.verify(mr)
    except ValueError as e:
        raise e

    consensus.flag(blockchain, state, mr)

#Remove a holder's Merit.
#As Consensus doesn't track Merit, this just clears their pending MeritRemovals.
#This also removes any votes they may have in the SpamFilter.
proc remove*(
    consensus: Consensus,
    holder: uint16,
    merit: int
) {.forceCheck: [].} =
    consensus.malicious.del(holder)
    consensus.filters.send.remove(holder, merit)
    consensus.filters.data.remove(holder, merit)

#Get a Transaction's unfinalized parents.
proc getUnfinalizedParents(
    consensus: Consensus,
    tx: Transaction
): seq[Hash[256]] {.forceCheck: [].} =
    #If this Transaction doesn't have inputs with statuses, don't do anything.
    if not (
        (tx of Claim) or
        (
            (tx of Data) and
            (cast[Data](tx).isFirstData)
        )
    ):
        #Make sure every input was already finalized.
        for input in tx.inputs:
            try:
                if consensus.getStatus(input.hash).merit == -1:
                    result.add(input.hash)
            except IndexError as e:
                doAssert(false, "Couldn't get the Status of a Transaction used as an input in the specified Transaction: " & e.msg)

#Mark all mentioned packets as mentioned, reset pending, finalize finalized Transactions, and check close Transactions.
proc archive*(
    consensus: Consensus,
    state: State,
    shifted: seq[VerificationPacket],
    elements: seq[BlockElement],
    popped: Epoch,
    incd: uint16,
    decd: int
) {.forceCheck: [].} =
    try:
        for packet in shifted:
            #Delete every mentioned hash in the Block from unmentioned.
            consensus.unmentioned.excl(packet.hash)

            #Clear the Status's pending VerificationPacket.
            var status: TransactionStatus = consensus.getStatus(packet.hash)
            status.pending = newSignedVerificationPacketObj(packet.hash)
            status.signatures = initTable[uint16, BLSSignature]()

            #Since this is a ref, we don't need to set it back.
            #We would if it needed to be saved to the DB, but the pending data isn't.
    except IndexError as e:
        doAssert(false, "Newly archived Transaction doesn't have a TransactionStatus: " & e.msg)

    #Update the Epoch for every unmentioned Transaction.
    for hash in consensus.unmentioned:
        consensus.incEpoch(hash)
        consensus.db.addUnmentioned(hash)

    #Update the signature/nonces of every holder.
    proc updateSignatureAndNonce(
        holder: uint16,
        nonce: int
    ) {.forceCheck: [].} =
        try:
            if consensus.archived[holder] < nonce:
                #Remove signatures.
                #There won't be any if we only ever saw the unsigned version of this Element.
                for s in 1 .. nonce - consensus.archived[holder]:
                    if consensus.signatures[holder].len == 0:
                        break
                    consensus.signatures[holder].delete(0)
                    consensus.db.deleteSignature(holder, consensus.archived[holder] + s)

                #Update the nonces.
                consensus.archived[holder] = nonce
                consensus.db.saveArchived(holder, nonce)
        except KeyError as e:
            doAssert(false, "Block had Elements with an invalid holder: " & e.msg)

    try:
        for elem in elements:
            case elem:
                of SendDifficulty as sd:
                    updateSignatureAndNonce(sd.holder, sd.nonce)
                of DataDifficulty as dd:
                    updateSignatureAndNonce(dd.holder, dd.nonce)
                of MeritRemoval as _:
                    discard
                else:
                    doAssert(false, "Unsupported Block Element.")
    except KeyError:
        doAssert(false, "Tried to archive an Element for a non-existent holder.")

    #Transactions finalized out of order.
    var outOfOrder: HashSet[Hash[256]] = initHashSet[Hash[256]]()
    #Mark every hash in this Epoch as out of Epochs.
    for hash in popped.keys():
        #Skip Transaction we verified out of order.
        if outOfOrder.contains(hash):
            continue

        var parents: seq[Hash[256]] = @[hash]
        while parents.len != 0:
            #Grab the last parent.
            var parent: Hash[256] = parents.pop()

            #Skip this Transaction if we already verified it.
            if outOfOrder.contains(parent):
                continue

            #Grab the Transaction.
            var tx: Transaction
            try:
                tx = consensus.functions.transactions.getTransaction(parent)
            except IndexError as e:
                doAssert(false, "Couldn't get a Transaction that's out of Epochs: " & e.msg)

            #Grab this Transaction's unfinalized parents.
            var newParents: seq[Hash[256]] = consensus.getUnfinalizedParents(tx)

            #If all the parents are finalized, finalize this Transaction.
            if newParents.len == 0:
                try:
                    consensus.finalize(state, parent, popped[hash])
                except KeyError as e:
                    doAssert(false, "Couldn't get a value from a Table using a key from .keys(): " & e.msg)
                outOfOrder.incl(parent)
            else:
                #Else, add back this Transaction, and then add the new parents.
                parents.add(parent)
                parents &= newParents

    #Reclaulcate every close Status.
    var toDelete: seq[Hash[256]] = @[]
    for hash in consensus.close:
        var status: TransactionStatus
        try:
            status = consensus.getStatus(hash)
        except IndexError:
            doAssert(false, "Couldn't get the status of a Transaction that's close to being verified: " & $hash)

        #Remove finalized Transactions.
        if status.merit != -1:
            toDelete.add(hash)
            continue

        #Recalculate Merit.
        consensus.calculateMerit(state, hash, status)
        #Remove verified Transactions.
        if status.verified:
            toDelete.add(hash)
            continue

    #Delete all close hashes marked for deletion.
    for hash in toDelete:
        consensus.close.excl(hash)

    #Update the filters.
    if decd == -1:
        consensus.filters.send.handleBlock(incd, state[incd])
        consensus.filters.data.handleBlock(incd, state[incd])
    else:
        consensus.filters.send.handleBlock(incd, state[incd], uint16(decd), state[uint16(decd)])
        consensus.filters.data.handleBlock(incd, state[incd], uint16(decd), state[uint16(decd)])

    #If the holder just got their first vote, make sure their difficulty is counted.
    if state[incd] == 50:
        try:
            consensus.filters.send.update(incd, state[incd], consensus.db.loadSendDifficulty(incd))
        except DBReadError:
            discard

        try:
            consensus.filters.data.update(incd, state[incd], consensus.db.loadDataDifficulty(incd))
        except DBReadError:
            discard

    #If the amount of holders increased, update the signatures and archived nonce tables.
    if state.holders.len > consensus.archived.len:
        consensus.signatures[uint16(consensus.archived.len)] = @[]
        consensus.archived[uint16(consensus.archived.len)] = -1
