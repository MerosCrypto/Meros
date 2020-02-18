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

#Input toString function.
from ../Filesystem/DB/TransactionsDB import toString

#Transactions lib.
import ../Transactions/Transactions

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
import TransactionStatus as TransactionStatusFile
export TransactionStatusFile

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

#Add a Merit Removal's Transaction.
proc addMeritRemovalTransaction*(
    consensus: Consensus,
    tx: Transaction
) {.inline, forceCheck: [].} =
    consensus.db.saveTransaction(tx)

#Get a Merit Removal's Transaction.
proc getMeritRemovalTransaction*(
    consensus: Consensus,
    hash: Hash[256]
): Transaction {.forceCheck: [
    IndexError
].} =
    try:
        result = consensus.db.loadTransaction(hash)
    except DBReadError as e:
        raise newLoggedException(IndexError, e.msg)

#Verify a MeritRemoval's validity.
proc verify*(
    consensus: Consensus,
    mr: MeritRemoval,
    lookup: seq[BLSPublicKey]
) {.forceCheck: [
    ValueError,
    DataExists
].} =
    if consensus.db.hasMeritRemoval(mr):
        raise newLoggedException(DataExists, "MeritRemoval already exists.")

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
                raise newLoggedException(ValueError, "Unknown hash.")

            if (not status.holders.contains(mr.holder)) or status.signatures.hasKey(mr.holder):
                raise newLoggedException(ValueError, "Verification isn't archived.")

        var
            inputs: HashSet[string] = initHashSet[string]()
            tx: Transaction
        try:
            tx = consensus.functions.transactions.getTransaction(hash)
        except IndexError:
            try:
                tx = consensus.getMeritRemovalTransaction(hash)
            except IndexError:
                raise newLoggedException(ValueError, "Unknown Transaction verified in first Element.")

        for input in tx.inputs:
            inputs.incl(input.toString())

        var secondHash: Hash[256]
        case mr.element2:
            of Verification as verif:
                secondHash = verif.hash
            of MeritRemovalVerificationPacket as packet:
                #Verify this Packet actually includes this holder.
                var found: bool = false
                for holder in packet.holders:
                    if holder == lookup[mr.holder]:
                        found = true
                if not found:
                    raise newLoggedException(ValueError, "Merit Removal Verification Packet doesn't include this holder.")

                secondHash = packet.hash
            else:
                raise newLoggedException(ValueError, "Invalid second Element.")

        if hash == secondHash:
            raise newLoggedException(ValueError, "MeritRemoval claims a Transaction competes with itself.")

        try:
            tx = consensus.functions.transactions.getTransaction(secondHash)
        except IndexError:
            try:
                tx = consensus.getMeritRemovalTransaction(hash)
            except IndexError:
                raise newLoggedException(ValueError, "Unknown Transaction verified in second Element.")

        for input in tx.inputs:
            if inputs.contains(input.toString()):
                return
        raise newLoggedException(ValueError, "Transactions don't compete.")

    proc checkSecondSameNonce(
        nonce: int
    ) {.forceCheck: [
        ValueError
    ].} =
        try:
            if mr.partial and ((nonce > consensus.archived[mr.holder]) or (mr.element1 != consensus.db.load(mr.holder, nonce))):
                raise newLoggedException(ValueError, "First Element isn't archived.")
        except KeyError:
            raise newLoggedException(ValueError, "MeritRemoval has an invalid holder.")
        except DBReadError as e:
            panic("Nonce was within bounds yet no Element could be loaded: " & e.msg)

        case mr.element2:
            of Verification as _:
                raise newLoggedException(ValueError, "Invalid second Element.")
            of MeritRemovalVerificationPacket as _:
                raise newLoggedException(ValueError, "Invalid second Element.")
            of SendDifficulty as sd:
                if nonce != sd.nonce:
                    raise newLoggedException(ValueError, "Second Element has a distinct nonce.")

                if (
                    (mr.element1 of SendDifficulty) and
                    (cast[SendDifficulty](mr.element1).difficulty == sd.difficulty)
                ):
                    raise newLoggedException(ValueError, "Elements are the same.")
            of DataDifficulty as dd:
                if nonce != dd.nonce:
                    raise newLoggedException(ValueError, "Second Element has a distinct nonce.")

                if (
                    (mr.element1 of DataDifficulty) and
                    (cast[DataDifficulty](mr.element1).difficulty == dd.difficulty)
                ):
                    raise newLoggedException(ValueError, "Elements are the same.")
            else:
                panic("Unsupported MeritRemoval Element.")

    try:
        case mr.element1:
            of Verification as verif:
                checkSecondCompeting(verif.hash)
            of MeritRemovalVerificationPacket as packet:
                #Verify this Packet actually includes this holder.
                var found: bool = false
                for holder in packet.holders:
                    if holder == lookup[mr.holder]:
                        found = true
                if not found:
                    raise newLoggedException(ValueError, "Merit Removal Verification Packet doesn't include this holder.")

                checkSecondCompeting(packet.hash)
            of SendDifficulty as sd:
                checkSecondSameNonce(sd.nonce)
            of DataDifficulty as dd:
                checkSecondSameNonce(dd.nonce)
            else:
                panic("Unsupported MeritRemoval Element.")
    except ValueError as e:
        raise e

#Flag a MeritHolder as malicious.
proc flag*(
    consensus: var Consensus,
    blockchain: Blockchain,
    state: State,
    removal: MeritRemoval
) {.forceCheck: [].} =
    #Make sure there's a seq.
    if not consensus.malicious.hasKey(removal.holder):
        consensus.malicious[removal.holder] = @[]

    #Return the MeritRemoval if it's already flagged.
    try:
        for mr in consensus.malicious[removal.holder]:
            if removal.reason == mr.reason:
                logDebug "We already have this MR"
                return
    except KeyError as e:
        panic("Failed to get the MeritRemovals for a holder which just had their seq created: " & e.msg)

    #Save the MeritRemoval to the database.
    consensus.db.save(removal)

    #Add the MeritRemoval, if it's signed.
    if removal of SignedMeritRemoval:
        try:
            consensus.malicious[removal.holder].add(cast[SignedMeritRemoval](removal))
            consensus.db.saveMaliciousProof(cast[SignedMeritRemoval](removal))
        except KeyError as e:
            panic("Couldn't add a MeritRemoval to a seq we've confirmed exists: " & e.msg)

    #Reclaulcate the affected Transactions in Epochs.
    var
        status: TransactionStatus
        blockInEpochs: Block
    for b in max(blockchain.height - 5, 0) ..< blockchain.height:
        try:
            blockInEpochs = blockchain[b]
        except IndexError as e:
            panic("Couldn't get a Block from the Blockchain despite iterating up to the height: " & e.msg)

        for packet in blockInEpochs.body.packets:
            try:
                status = consensus.getStatus(packet.hash)
            except IndexError as e:
                panic("Couldn't get the status of a Transaction in Epochs at one point: " & e.msg)

            #Don't recalculate Transactions which have already finalized.
            if status.merit != -1:
                continue

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
            panic("Couldn't get the status of a Transaction yet to be mentioned in Epochs: " & e.msg)

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
    consensus: var Consensus,
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
            panic("Parent Transaction doesn't have a status.")

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
                        panic("Competing Transaction doesn't have a Status despite being marked as a spender.")

    #Set the status.
    consensus.setStatus(tx.hash, status)

    #Mark the Transaction as unmentioned.
    consensus.setUnmentioned(tx.hash)

#Add a VerificationPacket.
proc add*(
    consensus: var Consensus,
    state: State,
    packet: VerificationPacket
) {.forceCheck: [].} =
    var status: TransactionStatus
    #Get the status.
    try:
        status = consensus.getStatus(packet.hash)
    #If there's no TX status, the TX wasn't registered.
    except IndexError:
        panic("Adding a VerificationPacket for a non-existent Transaction.")

    #Add the packet.
    status.add(packet)
    #Calculate Merit.
    consensus.calculateMerit(state, packet.hash, status)
    #Set the status.
    consensus.setStatus(packet.hash, status)

#Add a SignedVerification.
proc add*(
    consensus: var Consensus,
    state: State,
    verif: SignedVerification
) {.forceCheck: [
    ValueError,
    DataExists,
    MaliciousMeritHolder
].} =
    #Verify the holder exists.
    if verif.holder >= uint16(state.holders.len):
        raise newLoggedException(ValueError, "Invalid holder.")

    #Verify the signature.
    try:
        if not verif.signature.verify(
            newBLSAggregationInfo(
                state.holders[verif.holder],
                verif.serializeWithoutHolder()
            )
        ):
            raise newLoggedException(ValueError, "Invalid SignedVerification signature.")
    except BLSError:
        panic("Holder with an infinite key entered the system.")

    #Get the Transaction.
    var tx: Transaction
    try:
        tx = consensus.functions.transactions.getTransaction(verif.hash)
    except IndexError:
        raise newLoggedException(ValueError, "Unknown Verification.")

    #Check if this holder verified a competing Transaction.
    for input in tx.inputs:
        var spenders: seq[Hash[256]] = consensus.functions.transactions.getSpenders(input)
        for spender in spenders:
            if spender == verif.hash:
                continue

            #Get the spender's status.
            var status: TransactionStatus
            try:
                status = consensus.getStatus(spender)
            except IndexError as e:
                panic("Couldn't get the status of a Transaction: " & e.msg)

            if status.holders.contains(verif.holder):
                try:
                    var partial: bool = not status.signatures.hasKey(verif.holder)
                    raise newMaliciousMeritHolder(
                        "Verifier verified competing Transactions.",
                        newSignedMeritRemoval(
                            verif.holder,
                            partial,
                            newVerificationObj(spender),
                            verif,
                            if partial:
                                verif.signature
                            else:
                                @[status.signatures[verif.holder], verif.signature].aggregate()
                            , state.holders
                        )
                    )
                except KeyError as e:
                    panic("Couldn't get a holder's unarchived Verification signature: " & e.msg)

    #Get the status.
    var status: TransactionStatus
    try:
        status = consensus.getStatus(verif.hash)
    except IndexError:
        panic("SignedVerification added for a Transaction which was not registered.")

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
    consensus: var Consensus,
    state: State,
    sendDiff: SendDifficulty
) {.forceCheck: [].} =
    consensus.db.save(sendDiff)
    consensus.filters.send.update(sendDiff.holder, state[sendDiff.holder], sendDiff.difficulty)

#Add a SignedSendDifficulty.
proc add*(
    consensus: var Consensus,
    state: State,
    sendDiff: SignedSendDifficulty
) {.forceCheck: [
    ValueError,
    DataExists,
    MaliciousMeritHolder
].} =
    #Verify the holder exists.
    if sendDiff.holder >= uint16(state.holders.len):
        raise newLoggedException(ValueError, "Invalid holder.")

    #Verify the SendDifficulty's signature.
    try:
        if not sendDiff.signature.verify(
            newBLSAggregationInfo(
                state.holders[sendDiff.holder],
                sendDiff.serializeWithoutHolder()
            )
        ):
            raise newLoggedException(ValueError, "Invalid SendDifficulty signature.")
    except BLSError:
        raise newLoggedException(ValueError, "Invalid SendDifficulty signature.")

    #Verify the nonce. This is done in NetworkSync for non-signed versions.
    if sendDiff.nonce != consensus.db.load(sendDiff.holder) + 1:
        if sendDiff.nonce <= consensus.db.load(sendDiff.holder):
            #If this isn't the existing Element, it's cause for a MeritRemoval.
            var other: BlockElement
            try:
                other = consensus.db.load(sendDiff.holder, sendDiff.nonce)
            except DBReadError as e:
                panic("Couldn't read a Block Element with a nonce lower than the holder's current nonce: " & e.msg)

            if other == sendDiff:
                raise newLoggedException(DataExists, "Already added this SendDifficulty.")

            try:
                var partial: bool = sendDiff.nonce <= consensus.archived[sendDiff.holder]
                raise newMaliciousMeritHolder(
                    "SendDifficulty shares a nonce with a different Element.",
                    newSignedMeritRemoval(
                        sendDiff.holder,
                        partial,
                        other,
                        sendDiff,
                        if partial:
                            sendDiff.signature
                        else:
                            @[
                                consensus.signatures[sendDiff.holder][sendDiff.nonce - consensus.archived[sendDiff.holder] - 1],
                                sendDiff.signature
                            ].aggregate()
                        , state.holders
                    )
                )
            except KeyError as e:
                panic("Either couldn't get a holder's archived nonce or one of their signatures: " & e.msg)

        raise newLoggedException(ValueError, "SendDifficulty skips a nonce.")

    #Add the SendDifficulty.
    consensus.add(state, cast[SendDifficulty](sendDiff))

    #Save the signature.
    try:
        consensus.signatures[sendDiff.holder].add(sendDiff.signature)
        consensus.db.saveSignature(sendDiff.holder, sendDiff.nonce, sendDiff.signature)
    except KeyError as e:
        panic("Couldn't cache a signature: " & e.msg)

#Add a DataDifficulty.
proc add*(
    consensus: var Consensus,
    state: State,
    dataDiff: DataDifficulty
) {.forceCheck: [].} =
    consensus.db.save(dataDiff)
    consensus.filters.data.update(dataDiff.holder, state[dataDiff.holder], dataDiff.difficulty)

#Add a SignedDataDifficulty.
proc add*(
    consensus: var Consensus,
    state: State,
    dataDiff: SignedDataDifficulty
) {.forceCheck: [
    ValueError,
    DataExists,
    MaliciousMeritHolder
].} =
    #Verify the holder exists.
    if dataDiff.holder >= uint16(state.holders.len):
        raise newLoggedException(ValueError, "Invalid holder.")

    #Verify the DataDifficulty's signature.
    try:
        if not dataDiff.signature.verify(
            newBLSAggregationInfo(
                state.holders[dataDiff.holder],
                dataDiff.serializeWithoutHolder()
            )
        ):
            raise newLoggedException(ValueError, "Invalid DataDifficulty signature.")
    except BLSError:
        raise newLoggedException(ValueError, "Invalid DataDifficulty signature.")

    #Verify the nonce. This is done in NetworkSync for non-signed versions.
    if dataDiff.nonce != consensus.db.load(dataDiff.holder) + 1:
        if dataDiff.nonce <= consensus.db.load(dataDiff.holder):
            #If this isn't the existing Element, it's cause for a MeritRemoval.
            var other: BlockElement
            try:
                other = consensus.db.load(dataDiff.holder, dataDiff.nonce)
            except DBReadError as e:
                panic("Couldn't read a Block Element with a nonce lower than the holder's current nonce: " & e.msg)

            if other == dataDiff:
                raise newLoggedException(DataExists, "Already added this DataDifficulty.")

            try:
                var partial: bool = dataDiff.nonce <= consensus.archived[dataDiff.holder]
                raise newMaliciousMeritHolder(
                    "DataDifficulty shares a nonce with a different Element.",
                    newSignedMeritRemoval(
                        dataDiff.holder,
                        partial,
                        other,
                        dataDiff,
                        if partial:
                            dataDiff.signature
                        else:
                            @[
                                consensus.signatures[dataDiff.holder][dataDiff.nonce - consensus.archived[dataDiff.holder] - 1],
                                dataDiff.signature
                            ].aggregate()
                        , state.holders
                    )
                )
            except KeyError as e:
                panic("Either couldn't get a holder's archived nonce or one of their signatures: " & e.msg)

        raise newLoggedException(ValueError, "DataDifficulty skips a nonce.")

    #Add the DataDifficulty.
    consensus.add(state, cast[DataDifficulty](dataDiff))

    #Save the signature.
    try:
        consensus.signatures[dataDiff.holder].add(dataDiff.signature)
        consensus.db.saveSignature(dataDiff.holder, dataDiff.nonce, dataDiff.signature)
    except KeyError as e:
        panic("Couldn't cache a signature: " & e.msg)

#Add a SignedMeritRemoval.
proc add*(
    consensus: var Consensus,
    blockchain: Blockchain,
    state: State,
    mr: SignedMeritRemoval
) {.forceCheck: [
    ValueError,
    DataExists
].} =
    #Verify the MeritRemoval's signature.
    if not mr.signature.verify(mr.agInfo(state.holders[mr.holder])):
        raise newLoggedException(ValueError, "Invalid MeritRemoval signature.")

    try:
        consensus.verify(mr, state.holders)
    except ValueError as e:
        raise e
    except DataExists as e:
        raise e

    consensus.flag(blockchain, state, mr)

#Remove a holder's Merit.
#As Consensus doesn't track Merit, this just clears their pending MeritRemovals.
#This also removes any votes they may have in the SpamFilter.
proc remove*(
    consensus: var Consensus,
    mr: MeritRemoval,
    merit: int
) {.forceCheck: [].} =
    logInfo "Archiving Merit Removal", holder = mr.holder, reason = mr.reason

    #If the MeritRemoval was first found in a Block, it won't be in the cache or DB.
    var found: bool = false
    try:
        var m: int = 0
        while m < consensus.malicious[mr.holder].len:
            if mr.reason == consensus.malicious[mr.holder][m].reason:
                consensus.malicious[mr.holder].del(m)
                found = true
                break
            inc(m)

        if consensus.malicious[mr.holder].len == 0:
            consensus.malicious.del(mr.holder)
    except KeyError as e:
        panic("Tried to remove Merit from a holder without any Merit Removals: " & e.msg)
    except IndexError as e:
        panic("Tried to remove a Merit Removal from a holder without that Merit Removal: " & e.msg)

    if found:
        consensus.db.deleteMaliciousProof(mr)

    consensus.filters.send.remove(mr.holder, merit)
    consensus.filters.data.remove(mr.holder, merit)

    #If the removed MeritRemoval involved a SendDifficulty, DataDifficulty, or GasPrice, we need to:
    #- Save that the nonce was used.
    #- Update the difficulties/gas price.
    var usedNonces: HashSet[int] = consensus.db.loadMeritRemovalNonces(mr.holder)
    proc updateIfTail(
        consensus: var Consensus,
        elem: Element
    ) {.forceCheck: [].} =
        case elem:
            of Verification as _:
                return

            of MeritRemovalVerificationPacket as _:
                return

            of SendDifficulty as sd:
                consensus.db.saveMeritRemovalNonce(mr.holder, sd.nonce)
                usedNonces.incl(sd.nonce)

                if sd.nonce == consensus.db.loadSendDifficultyNonce(sd.holder):
                    var
                        found: bool = false
                        other: BlockElement
                    for n in countdown(sd.nonce - 1, 0):
                        if usedNonces.contains(n):
                            continue

                        try:
                            other = consensus.db.load(sd.holder, n)
                        except DBReadError as e:
                            panic("Couldn't grab a BlockElement when iterating down from the last SendDifficulty: " & e.msg)
                        if other of SendDifficulty:
                            found = true
                            consensus.db.override(cast[SendDifficulty](other))
                            break

                    if not found:
                        consensus.db.deleteSendDifficulty(sd.holder)

            of DataDifficulty as dd:
                consensus.db.saveMeritRemovalNonce(mr.holder, dd.nonce)
                usedNonces.incl(dd.nonce)

                if dd.nonce == consensus.db.loadDataDifficultyNonce(dd.holder):
                    var
                        found: bool = false
                        other: BlockElement
                    for n in countdown(dd.nonce - 1, 0):
                        if usedNonces.contains(n):
                            continue

                        try:
                            other = consensus.db.load(dd.holder, n)
                        except DBReadError as e:
                            panic("Couldn't grab a BlockElement when iterating down from the last DataDifficulty: " & e.msg)
                        if other of DataDifficulty:
                            found = true
                            consensus.db.override(cast[DataDifficulty](other))
                            break

                    if not found:
                        consensus.db.deleteDataDifficulty(dd.holder)

            else:
                panic("Archiving a Merit Removal with an unknown Element.")

    updateIfTail(consensus, mr.element1)
    updateIfTail(consensus, mr.element2)

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
                panic("Couldn't get the Status of a Transaction used as an input in the specified Transaction: " & e.msg)

#Mark all mentioned packets as mentioned, reset pending, finalize finalized Transactions, and check close Transactions.
proc archive*(
    consensus: var Consensus,
    state: State,
    shifted: seq[VerificationPacket],
    elements: seq[BlockElement],
    popped: Epoch,
    incd: uint16,
    decd: int
) {.forceCheck: [].} =
    #Delete every mentioned hash in the Block from unmentioned.
    for packet in shifted:
        consensus.unmentioned.excl(packet.hash)

    #Update the Epoch for every unmentioned Transaction.
    for hash in consensus.unmentioned:
        consensus.incEpoch(hash)
        consensus.db.addUnmentioned(hash)

    #Update the signature/nonces of every holder.
    proc updateSignatureAndNonce(
        consensus: var Consensus,
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
            panic("Block had Elements with an invalid holder: " & e.msg)

    try:
        for elem in elements:
            case elem:
                of SendDifficulty as sd:
                    updateSignatureAndNonce(consensus, sd.holder, sd.nonce)
                of DataDifficulty as dd:
                    updateSignatureAndNonce(consensus, dd.holder, dd.nonce)
                of MeritRemoval as _:
                    discard
                else:
                    panic("Unsupported Block Element.")
    except KeyError:
        panic("Tried to archive an Element for a non-existent holder.")

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
                panic("Couldn't get a Transaction that's out of Epochs: " & e.msg)

            #Grab this Transaction's unfinalized parents.
            var newParents: seq[Hash[256]] = consensus.getUnfinalizedParents(tx)

            #If all the parents are finalized, finalize this Transaction.
            if newParents.len == 0:
                try:
                    consensus.finalize(state, parent)
                except KeyError as e:
                    panic("Couldn't get a value from a Table using a key from .keys(): " & e.msg)
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
            panic("Couldn't get the status of a Transaction that's close to being verified: " & $hash)

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

proc revert*(
    consensus: var Consensus,
    blockchain: Blockchain,
    state: State,
    transactions: Transactions,
    height: int
) {.forceCheck: [].} =
    discard """
    We need to find the oldest Element nonce we're reverting past.
    We need to delete all Elements from that nonce (inclusive) to the tip.
    If we delete an Element at the tip which wasn't archived, we also need to delete its signature.
    We need to update the archived nonces.
    We need to make sure the SendDifficulty and DataDifficulty are updated accordingly.

    We need to delete malicious proofs we no longer have the signature for.
    We shouldn't need to touch the malicious cache.

    We need to revert the SpamFilters. We can do this by rebuilding them, however inefficient it is.

    We need to prune statuses of Transactions which are about to be pruned.
    We need to make sure to preserve a copy of Transactions in VC MRs which are about to be pruned, if the MRs are still in the malicious cache.
    """

    var
        aboutToBePruned: HashSet[Hash[256]]
        revertedToNonces: Table[uint16, int] = initTable[uint16, int]()
    for b in countdown(blockchain.height - 1, height):
        var revertedBlock: Block
        try:
            revertedBlock = blockchain[b]
        except IndexError as e:
            panic("Couldn't get a Block when iterating from the height to another height: " & e.msg)

        try:
            discard transactions[revertedBlock.header.hash]
            for hash in transactions.discoverTree(revertedBlock.header.hash):
                aboutToBePruned.incl(hash)
        except IndexError:
            discard

        for elem in revertedBlock.body.elements:
            case elem:
                of SendDifficulty as sd:
                    revertedToNonces[sd.holder] = sd.nonce
                of DataDifficulty as dd:
                    revertedToNonces[dd.holder] = dd.nonce
                of MeritRemoval as mr:
                    consensus.db.deleteMeritRemoval(mr)
                else:
                    panic("Unknown Element included in Block.")

    #Delete Elements which we reverted past.
    for holder in revertedToNonces.keys():
        try:
            for n in revertedToNonces[holder] .. consensus.db.load(holder):
                consensus.db.delete(holder, n)

            #Update the holder's nonce.
            consensus.archived[holder] = revertedToNonces[holder] - 1
            consensus.db.override(holder, revertedToNonces[holder] - 1)

            #Also delete cached signatures since we wiped out Elements in the middle of their chain.
            consensus.signatures.del(holder)

            #Also update the SendDifficulty and DataDifficulty, if required.
            var
                usedNonces: HashSet[int] = consensus.db.loadMeritRemovalNonces(holder)
                found: bool = false
                other: BlockElement
            if consensus.db.loadSendDifficultyNonce(holder) > consensus.db.load(holder):
                for n in countdown(consensus.archived[holder], 0):
                    if usedNonces.contains(n):
                        continue

                    try:
                        other = consensus.db.load(holder, n)
                    except DBReadError as e:
                        panic("Couldn't grab a BlockElement when iterating down from the last archived nonce: " & e.msg)

                    if other of SendDifficulty:
                        found = true
                        consensus.db.override(cast[SendDifficulty](other))
                        break

                if not found:
                    consensus.db.deleteSendDifficulty(holder)

            found = false
            if consensus.db.loadDataDifficultyNonce(holder) > consensus.db.load(holder):
                for n in countdown(consensus.archived[holder], 0):
                    if usedNonces.contains(n):
                        continue

                    try:
                        other = consensus.db.load(holder, n)
                    except DBReadError as e:
                        panic("Couldn't grab a BlockElement when iterating down from the last archived nonce: " & e.msg)

                    if other of DataDifficulty:
                        found = true
                        consensus.db.override(cast[DataDifficulty](other))
                        break

                if not found:
                    consensus.db.deleteDataDifficulty(holder)
        except KeyError as e:
            panic("Couldn't get the reverted to nonce/archived nonce of a holder with one: " & e.msg)

    #Rebuild the filters.
    consensus.filters.send = newSpamFilterObj(consensus.filters.send.startDifficulty)
    consensus.filters.data = newSpamFilterObj(consensus.filters.data.startDifficulty)
    for h in 0 ..< state.holders.len:
        try:
            consensus.filters.send.update(uint16(h), state[uint16(h)], consensus.db.loadSendDifficulty(uint16(h)))
        except DBReadError:
            discard

        try:
            consensus.filters.data.update(uint16(h), state[uint16(h)], consensus.db.loadDataDifficulty(uint16(h)))
        except DBReadError:
            discard

    #Prune statuses of Transactions about to be pruned.
    for hash in aboutToBePruned:
        consensus.delete(hash)

    #Iterate over every pending MeritRemoval.
    #If it's a VC MeritRemoval, and the verified Transaction is about to be pruned, back it up.
    for holder in consensus.malicious.keys():
        try:
            for mr in consensus.malicious[holder]:
                case mr.element1:
                    of Verification as verif:
                        if aboutToBePruned.contains(verif.hash):
                            consensus.addMeritRemovalTransaction(transactions[verif.hash])
                    of MeritRemovalVerificationPacket as packet:
                        if aboutToBePruned.contains(packet.hash):
                            consensus.addMeritRemovalTransaction(transactions[packet.hash])
                    else:
                        discard
        except KeyError as e:
            panic("Couldn't get a malicious Merit Holder's Merit Removals: " & e.msg)
        except IndexError:
            panic("Couldn't get a Transaction that is about to be pruned.")

proc postRevert*(
    consensus: var Consensus,
    blockchain: Blockchain,
    state: State,
    transactions: Transactions
) {.forceCheck: [].} =
    discard """
    We need to add statuses of Transactions which are back in the Transactions cache to the Consensus cache.
    This requires recalculating their Epoch.
    We need to remove Verifications we no longer have the signatures for from every status in the cache.

    We need to revert close. We can do this by rebuilding it, however inefficient it is.

    We need to revert unmentioned. We can do this by rebuilding it, however inefficient it is.
    """

    var revertedStatuses: Table[Hash[256], TransactionStatus]
    for hash in consensus.cachedTransactions:
        try:
            revertedStatuses[hash] = consensus.getStatus(hash)
        except IndexError as e:
            panic("Transaction with a status in the cache doesn't have a status: " & e.msg)

    for hash in transactions.transactions.keys():
        if not revertedStatuses.hasKey(hash):
            try:
                revertedStatuses[hash] = consensus.getStatus(hash)
            except IndexError as e:
                panic("Transaction in the cache doesn't have a status: " & e.msg)

    #Iterate over the last 5 blocks and find out:
    #- When Transactions were mentioned.
    #- What holders have archived Verifications.
    var
        mentioned: Table[Hash[256], int] = initTable[Hash[256], int]()
        holders: Table[Hash[256], HashSet[uint16]] = initTable[Hash[256], HashSet[uint16]]()
    for i in max(blockchain.height - 5, 0) ..< blockchain.height:
        try:
            for packet in blockchain[i].body.packets:
                #If we haven't seen this Transaction yet, register it and create a HashSet.
                if not mentioned.hasKey(packet.hash):
                    mentioned[packet.hash] = i
                    holders[packet.hash] = initHashSet[uint16]()

                #Add the holders to the set.
                for holder in packet.holders:
                    try:
                        holders[packet.hash].incl(holder)
                    except KeyError as e:
                        panic("Packet within the last 5 blocks doesn't have a holders set initialized: " & e.msg)
        except IndexError as e:
            panic("Couldn't get a Block when iterating from 0 to the height: " & e.msg)

    #Clear unmentioned and close.
    consensus.unmentioned = initHashSet[Hash[256]]()
    consensus.close = initHashSet[Hash[256]]()

    #Update merit, holders, epoch, unmentioned, close, and verified.
    var status: TransactionStatus
    for hash in revertedStatuses.keys():
        #Grab the status.
        try:
            status = revertedStatuses[hash]
        except KeyError as e:
            panic("Couldn't grab a status that's in the newly formed cache: " & e.msg)

        #Set merit to -1 so this TransactionStatus is registered as pending.
        status.merit = -1

        #Set the holders and epoch.
        try:
            status.holders = holders[hash]
            status.epoch = mentioned[hash] + 6
        #If this raised a KeyError, they were never mentioned.
        except KeyError:
            status.holders = initHashSet[uint16]()
            consensus.unmentioned.incl(hash)
            status.epoch = blockchain.height + 6

        #Add back the pending holders.
        for holder in status.pending:
            status.holders.incl(holder)

        #Mark it as unverified until proven otherwise.
        if status.verified:
            status.verified = false
            consensus.functions.transactions.unverify(hash)

        #Calculate its Merit.
        try:
            consensus.calculateMeritSingle(state, transactions[hash], status)
        except IndexError as e:
            panic("Failed to get a Transaction which has a status: " & e.msg)

        #Save back the status.
        #If it was verified, calculateMeritSingle will save it.
        if not status.verified:
            try:
                consensus.setStatus(hash, revertedStatuses[hash])
            except KeyError as e:
                panic("Key retrieved via .keys() thre a KeyError: " & e.msg)
