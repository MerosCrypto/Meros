#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#GlobalFunctionBox object.
import ../../../objects/GlobalFunctionBoxObj

#Consensus DB lib.
import ../../Filesystem/DB/ConsensusDB

#Transaction object.
import ../../Transactions/Transaction

#State lib.
import ../../Merit/State

#Element libs.
import ../Elements/Elements

#TransactionStatus object.
import TransactionStatusObj
export TransactionStatusObj

#SpamFilter object.
import SpamFilterObj

#Sets standard lib.
import sets

#Tables standard lib.
import tables

#Consensus object.
type Consensus* = ref object
    #Global Functions.
    functions*: GlobalFunctionBox
    #DB.
    db*: DB

    #Filters.
    filters*: tuple[send: SpamFilter, data: SpamFilter]
    #Nickname -> MeritRemoval(s).
    malicious*: Table[uint16, seq[MeritRemoval]]

    #Statuses of Transactions not yet out of Epochs.
    statuses: Table[Hash[384], TransactionStatus]
    #Statuses which are close to becoming verified.
    #Every Transaction in this Table is checked when new Blocks are added to see if they crossed the threshold.
    close*: HashSet[Hash[384]]

    #Transactions which haven't been mentioned in Epochs.
    unmentioned*: HashSet[Hash[384]]

#Consensus constructor.
proc newConsensusObj*(
    functions: GlobalFunctionBox,
    db: DB,
    state: State,
    sendDiff: Hash[384],
    dataDiff: Hash[384]
): Consensus {.forceCheck: [].} =
    #Create the Consensus object.
    result = Consensus(
        functions: functions,
        db: db,

        filters: (
            send: newSpamFilterObj(sendDiff),
            data: newSpamFilterObj(dataDiff)
        ),
        malicious: initTable[uint16, seq[MeritRemoval]](),

        statuses: initTable[Hash[384], TransactionStatus](),
        close: initHashSet[Hash[384]](),

        unmentioned: initHashSet[Hash[384]]()
    )

    #Load statuses still in Epochs.
    #Just like Epochs, this first requires loading the old last 5 Blocks and then the current last 5 Blocks.
    var
        height: int = functions.merit.getHeight()
        old: seq[Hash[384]] = @[]
    try:
        for i in max(height - 10, 0) ..< height - 5:
            for packet in functions.merit.getBlockByNonce(i).body.packets:
                old.add(packet.hash)

        for i in max(height - 5, 0) ..< height:
            for packet in functions.merit.getBlockByNonce(i).body.packets:
                try:
                    result.statuses[packet.hash] = result.db.load(packet.hash)
                except DBReadError:
                    doAssert(false, "Transaction archived on the Blockchain doesn't have a status.")

                #If this Transaction is close to being confirmed, add it to close.
                try:
                    var merit: int = 0
                    for holder in result.statuses[packet.hash].holders:
                        if not result.malicious.hasKey(holder):
                            merit += state[holder]
                    if (
                        (not result.statuses[packet.hash].verified) and
                        (merit >= state.nodeThresholdAt(result.statuses[packet.hash].epoch) - 5)
                    ):
                        result.close.incl(packet.hash)
                except KeyError as e:
                    doAssert(false, "Couldn't get a status we just added to the statuses table: " & e.msg)
    except IndexError as e:
        doAssert(false, "Couldn't get a Block on the Blockchain: " & e.msg)

    #Delete old Transaction statuses.
    for oldStatus in old:
        result.statuses.del(oldStatus)
        result.close.excl(oldStatus)

    #Load unmentioned Transactions.
    var unmentioned: seq[Hash[384]] = result.db.loadUnmentioned()
    for hash in unmentioned:
        result.unmentioned.incl(hash)

#Get all pending Verification Packets and the aggregate signature.
proc getPending*(
    consensus: Consensus
): tuple[
    packets: seq[VerificationPacket],
    aggregate: BLSSignature
] {.forceCheck: [].} =
    for status in consensus.statuses.values():
        if status.pending.holders.len != 0:
            result.packets.add(status.pending)
            if result.aggregate.isInf:
                result.aggregate = status.pending.signature
            else:
                result.aggregate = @[result.aggregate, status.pending.signature].aggregate()

#Set a Transaction as unmentioned.
proc setUnmentioned*(
    consensus: Consensus,
    hash: Hash[384]
) {.forceCheck: [].} =
    consensus.unmentioned.incl(hash)

#Set a Transaction's status.
proc setStatus*(
    consensus: Consensus,
    hash: Hash[384],
    status: TransactionStatus
) {.forceCheck: [].} =
    consensus.statuses[hash] = status
    consensus.db.save(hash, status)

#Get a Transaction's statuses.
proc getStatus*(
    consensus: Consensus,
    hash: Hash[384]
): TransactionStatus {.forceCheck: [
    IndexError
].} =
    if consensus.statuses.hasKey(hash):
        try:
            return consensus.statuses[hash]
        except KeyError as e:
            doAssert(false, "Couldn't get a Status from the cache when the cache has the key: " & e.msg)

    try:
        result = consensus.db.load(hash)
    except DBReadError:
        raise newException(IndexError, "Transaction doesn't have a status.")

    #Add the Transaction to the cache if it's not yet out of Epochs.
    if result.merit == -1:
        consensus.statuses[hash] = result

#Increment a Status's Epoch.
proc incEpoch*(
    consensus: Consensus,
    hash: Hash[384]
) {.forceCheck: [].} =
    var status: TransactionStatus
    try:
        status = consensus.getStatus(hash)
        inc(status.epoch)
    except ValueError:
        doAssert(false, "Couldn't increment the Epoch of a Status with an invalid hash.")
    except IndexError:
        doAssert(false, "Couldn't get the Status we're incrementing the Epoch of.")
    consensus.db.save(hash, status)

#Calculate a Transaction's Merit.
proc calculateMeritSingle(
    consensus: Consensus,
    state: State,
    tx: Transaction,
    status: TransactionStatus
) {.forceCheck: [].} =
    #If the Transaction is already verified, or it needs to default, return.
    if status.verified or status.competing:
        return

    #Calculate Merit.
    var merit: int = 0
    for holder in status.holders:
        #Skip malicious MeritHolders from Merit calculations.
        if not consensus.malicious.hasKey(holder):
            merit += state[holder]

    #Check if the Transaction crossed its threshold.
    if merit >= state.nodeThresholdAt(status.epoch):
        if state.nodeThresholdAt(status.epoch) < 0:
            doAssert(false, $tx.hash & " " & $status.epoch & " " & $state.processedBlocks)
        #Make sure all parents are verified.
        try:
            for input in tx.inputs:
                if (tx of Data) and (cast[Data](tx).isFirstData):
                    break

                if (
                    (not (consensus.functions.transactions.getTransaction(input.hash) of Mint)) and
                    (not consensus.getStatus(input.hash).verified)
                ):
                    return
        except IndexError as e:
            doAssert(false, "Couldn't get the Status of a Transaction that was the parent to this Transaction: " & e.msg)

        #Mark the Transaction as verified.
        status.verified = true
        consensus.db.save(tx.hash, status)
        consensus.functions.transactions.verify(tx.hash)
    elif merit >= state.nodeThresholdAt(status.epoch) - 5:
        consensus.close.incl(tx.hash)

#Calculate a Transaction's Merit. If it's verified, also check every descendant
proc calculateMerit*(
    consensus: Consensus,
    state: State,
    hash: Hash[384],
    statusArg: TransactionStatus
) {.forceCheck: [].} =
    var
        children: seq[Hash[384]] = @[hash]
        child: Hash[384]
        tx: Transaction
        status: TransactionStatus = statusArg
        wasVerified: bool

    while children.len != 0:
        child = children.pop()
        try:
            tx = consensus.functions.transactions.getTransaction(child)
            if child != hash:
                status = consensus.getStatus(child)
        except IndexError:
            doAssert(false, "Couldn't get the Transaction/Status for a Transaction we're calculating the Merit of.")
        wasVerified = status.verified

        consensus.calculateMeritSingle(
            state,
            tx,
            status
        )

        if (not wasVerified) and (status.verified):
            try:
                for o in 0 ..< tx.outputs.len:
                    var spenders: seq[Hash[384]] = consensus.functions.transactions.getSpenders(newFundedInput(child, o))
                    for spender in spenders:
                        children.add(spender)
            except IndexError as e:
                doAssert(false, "Couldn't get a child Transaction/child Transaction's Status we've marked as a spender of this Transaction: " & e.msg)

#Unverify a Transaction.
proc unverify*(
    consensus: Consensus,
    state: State,
    hash: Hash[384],
    status: TransactionStatus
) {.forceCheck: [].} =
    var
        children: seq[Hash[384]] = @[hash]
        child: Hash[384]
        tx: Transaction
        childStatus: TransactionStatus = status

    while children.len != 0:
        child = children.pop()
        try:
            tx = consensus.functions.transactions.getTransaction(child)
            if child != hash:
                childStatus = consensus.getStatus(child)
        except IndexError:
            doAssert(false, "Couldn't get the Transaction/Status for a Transaction we're calculating the Merit of.")

        #If this child was verified, unverify it and grab children.
        #Children of Transactions which aren't verified cann't be verified and therefore can be skipped.
        if childStatus.verified:
            echo "Verified Transaction was unverified: ", child
            childStatus.verified = false
            consensus.db.save(child, childStatus)
            consensus.statuses.del(child)

            try:
                for o in 0 ..< tx.outputs.len:
                    var spenders: seq[Hash[384]] = consensus.functions.transactions.getSpenders(newFundedInput(child, o))
                    for spender in spenders:
                        children.add(spender)
            except IndexError as e:
                doAssert(false, "Couldn't get a child Transaction/child Transaction's Status we've marked as a spender of this Transaction: " & e.msg)

            #Notify the Transactions DAG about the unverification.
            consensus.functions.transactions.unverify(child)

#Finalize a TransactionStatus.
proc finalize*(
    consensus: Consensus,
    state: State,
    hash: Hash[384],
    holders: seq[uint16]
) {.forceCheck: [].} =
    #Get the Transaction/Status.
    var
        tx: Transaction
        status: TransactionStatus
    try:
        tx = consensus.functions.transactions.getTransaction(hash)
        status = consensus.getStatus(hash)
    except IndexError as e:
        doAssert(false, "Couldn't get either the Transaction we're finalizing or its Status: " & e.msg)

    #Calculate the final Merit tally.
    status.merit = 0
    for holder in holders:
        #Add the Merit.
        status.merit += state[holder]

    #Make sure verified Transaction's Merit is above the node protocol threshold.
    if (status.verified) and (status.merit < state.protocolThresholdAt(state.processedBlocks)):
        #If it's now unverified, unverify the tree.
        consensus.unverify(state, hash, status)
    #If it wasn't verified, check if it actually was.
    elif (not status.verified) and (status.merit >= state.protocolThresholdAt(state.processedBlocks)):
        #Make sure all parents are verified.
        try:
            for input in tx.inputs:
                if (tx of Data) and (cast[Data](tx).isFirstData):
                    break

                if (
                    (not (consensus.functions.transactions.getTransaction(input.hash) of Mint)) and
                    (not consensus.getStatus(input.hash).verified)
                ):
                    consensus.statuses.del(hash)
                    return
        except IndexError as e:
            doAssert(false, "Couldn't get the Status of a Transaction that was the parent to this Transaction: " & e.msg)

        #Mark the Transaction as verified.
        status.verified = true
        consensus.functions.transactions.verify(tx.hash)

    #Check if the Transaction was beaten, if it's not already marked as beaten.
    if (not status.beaten) and (not status.verified):
        for input in tx.inputs:
            var spenders: seq[Hash[384]] = consensus.functions.transactions.getSpenders(input)
            for spender in spenders:
                try:
                    if consensus.getStatus(spender).verified:
                        status.beaten = true
                except IndexError as e:
                    doAssert(false, "Couldn't get the Status of a competing Transaction: " & e.msg)

    #Save the status.
    #This will cause a double save for the finalized TX in the unverified case.
    consensus.db.save(hash, status)
    consensus.statuses.del(hash)

#Provide debug access to the statuses table
when defined(merosTests):
    func statuses*(
        consensus: Consensus
    ): Table[Hash[384], TransactionStatus] {.inline, forceCheck: [].} =
        consensus.statuses
