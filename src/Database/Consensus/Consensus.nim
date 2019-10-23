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

#Element lib.
import Elements/Element
export Element

#TransactionStatus lib.
import TransactionStatus
export TransactionStatus

#Consensus object.
import objects/ConsensusObj
export ConsensusObj

#Serialize Verification lib.
import ../../Network/Serialize/Consensus/SerializeVerification

#Tables standard lib.
import tables

#Constructor wrapper.
proc newConsensus*(
    functions: GlobalFunctionBox,
    db: DB,
    sendDiff: Hash[384],
    dataDiff: Hash[384]
): Consensus {.forceCheck: [].} =
    newConsensusObj(functions, db, sendDiff, dataDiff)

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

    #Add the MeritRemoval.
    try:
        consensus.malicious[removal.holder].add(removal)
    except KeyError as e:
        doAssert(false, "Couldn't add a MeritRemoval to a seq we've confirmed exists: " & e.msg)

    #Reclaulcate the affected verified Transactions.
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

            if status.verified and status.holders.hasKey(removal.holder):
                var merit: int = 0
                for holder in status.holders.keys():
                    if not consensus.malicious.hasKey(holder):
                        merit += state[holder]

                if merit < state.protocolThresholdAt(status.epoch):
                    consensus.unverify(state, packet.hash, status)

proc checkMalicious*(
    consensus: Consensus,
    state: State,
    verif: SignedVerification
) {.forceCheck: [
    ValueError,
    #MaliciousMeritHolder
].} =
    #This method is called before the Element is added.
    #Only when we add the Element, do we verify its signature.
    #This method will fail to aggregate unless we set its AggregationInfo now.
    try:
        verif.signature.setAggregationInfo(
            newBLSAggregationInfo(
                state.holders[verif.holder],
                verif.serializeWithoutHolder()
            )
        )

        #We deleted the rest of this function for the No Consensus DAG branch.
        #This function called the function in MeritHolder which verified the signature.
        #Since we deleted the code which does that, along with the call, verify it now.
        if not verif.signature.verify():
            raise newException(ValueError, "Invalid SignedVerification signature.")
    except BLSError as e:
        doAssert(false, "Failed to create a BLS Aggregation Info: " & e.msg)

proc checkMalicious*(
    consensus: Consensus,
    packet: VerificationPacket
) {.forceCheck: [
    #MaliciousMeritHolder
].} =
    discard

#Register a Transaction.
proc register*(
    consensus: Consensus,
    state: State,
    tx: Transaction,
    height: int
) {.forceCheck: [].} =
    #Create the status.
    var status: TransactionStatus = newTransactionStatusObj(tx.hash, height + 6)

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
        var spenders: seq[Hash[384]] = consensus.functions.transactions.getSpenders(input)
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

    #If this Transaction is being added thanks to a handled VerificationPacket, apply it.
    if consensus.unknowns.hasKey(tx.hash):
        try:
            status.add(consensus.unknowns[tx.hash])

            #Delete from the unknowns table.
            consensus.unknowns.del(tx.hash)

            #Since we added a packet of verifiers, calculate the Merit.
            consensus.calculateMerit(state, tx.hash, status)
        except KeyError as e:
            doAssert(false, "Couldn't get unknown Verifications for a Transaction with unknown Verifications: " & e.msg)

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
    #If there's no TX status, the TX wasn't registered. Add it to unknowns.
    except IndexError:
        consensus.unknowns[packet.hash] = packet
        return

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
    DataExists
].} =
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
        fcRaise e

    #Calculate Merit.
    consensus.calculateMerit(state, verif.hash, status)
    #Set the status.
    consensus.setStatus(verif.hash, status)

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
    try:
        mr.signature.setAggregationInfo(mr.agInfo(state.holders[mr.holder]))
        if not mr.signature.verify():
            raise newException(ValueError, "Invalid MeritRemoval signature.")
    except BLSError as e:
        doAssert(false, "Failed to verify the MeritRemoval's signature: " & e.msg)

    #If this is a partial MeritRemoval, make sure the first Element is already archived on the Blockchain.
    if mr.partial:
        doAssert(false, "Partial MeritRemovals aren't supported.")

    #Same nonce.
    #This is only used for SendDifficulty, DataDifficulty, and GasPrice elements.
    #None of those are supported.
    elif false:
        discard

    #Verified competing elements.
    else:
        doAssert(false, "Verified competing MeritRemovals aren't supported.")

    consensus.flag(blockchain, state, mr)

#Remove a holder's Merit.
#As Consensus doesn't track Merit, this just clears their pending MeritRemovals.
proc remove*(
    consensus: Consensus,
    holder: uint16
) {.forceCheck: [].} =
    consensus.malicious.del(holder)

#Get a Transaction's unfinalized parents.
proc getUnfinalizedParents(
    consensus: Consensus,
    tx: Transaction
): seq[Hash[384]] {.forceCheck: [].} =
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

#For each provided Record, archive all Elements from the account's last archived to the provided nonce.
proc archive*(
    consensus: Consensus,
    state: State,
    shifted: Epoch,
    popped: Epoch
) {.forceCheck: [].} =
    #Delete every new Hash in Epoch from unmentioned.
    for hash in shifted.keys():
        consensus.unmentioned.del(hash)
    #Update the Epoch for every unmentioned Transaction.
    for hash in consensus.unmentioned.keys():
        consensus.incEpoch(hash)
        consensus.db.addUnmentioned(hash)

    #Transactions finalized out of order.
    var outOfOrder: Table[Hash[384], bool] = initTable[Hash[384], bool]()
    #Mark every hash in this Epoch as out of Epochs.
    for hash in popped.keys():
        #Skip Transaction we verified out of order.
        if outOfOrder.hasKey(hash):
            continue

        var parents: seq[Hash[384]] = @[hash]
        while parents.len != 0:
            #Grab the last parent.
            var parent: Hash[384] = parents.pop()

            #Skip this Transaction if we already verified it.
            if outOfOrder.hasKey(parent):
                continue

            #Grab the Transaction.
            var tx: Transaction
            try:
                tx = consensus.functions.transactions.getTransaction(parent)
            except IndexError as e:
                doAssert(false, "Couldn't get a Transaction that's out of Epochs: " & e.msg)

            #Grab this Transaction's unfinalized parents.
            var newParents: seq[Hash[384]] = consensus.getUnfinalizedParents(tx)

            #If all the parents are finalized, finalize this Transaction.
            if newParents.len == 0:
                consensus.finalize(state, parent)
                outOfOrder[parent] = true
            else:
                #Else, add back this Transaction, and then add the new parents.
                parents.add(parent)
                parents &= newParents

    #Reclaulcate every close Status.
    var toDelete: seq[Hash[384]] = @[]
    for hash in consensus.close.keys():
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
        consensus.close.del(hash)
