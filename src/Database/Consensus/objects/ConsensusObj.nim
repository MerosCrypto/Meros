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
    malicious*: Table[uint16, seq[SignedMeritRemoval]]

    #Statuses of Transactions not yet out of Epochs.
    statuses: Table[Hash[256], TransactionStatus]
    #Statuses which are close to becoming verified.
    #Every Transaction in this Table is checked when new Blocks are added to see if they crossed the threshold.
    close*: HashSet[Hash[256]]
    #Transactions which haven't been mentioned in Epochs.
    unmentioned*: HashSet[Hash[256]]

    #Signatures of unarchived elements.
    signatures*: Table[uint16, seq[BLSSignature]]
    #Archived nonces.
    archived*: Table[uint16, int]

#Consensus constructor.
proc newConsensusObj*(
    functions: GlobalFunctionBox,
    db: DB,
    state: State,
    sendDiff: Hash[256],
    dataDiff: Hash[256]
): Consensus {.forceCheck: [].} =
    #Create the Consensus object.
    result = Consensus(
        functions: functions,
        db: db,

        filters: (
            send: newSpamFilterObj(sendDiff),
            data: newSpamFilterObj(dataDiff)
        ),
        malicious: db.loadMaliciousProofs(),

        statuses: initTable[Hash[256], TransactionStatus](),
        close: initHashSet[Hash[256]](),
        unmentioned: initHashSet[Hash[256]](),

        archived: initTable[uint16, int]()
    )

    for h in 0 ..< state.holders.len:
        #Reload the filters.
        try:
            result.filters.send.update(uint16(h), state[uint16(h)], result.db.loadSendDifficulty(uint16(h)))
        except DBReadError:
            discard

        try:
            result.filters.data.update(uint16(h), state[uint16(h)], result.db.loadDataDifficulty(uint16(h)))
        except DBReadError:
            discard

        #Reload the table of archived nonces.
        result.archived[uint16(h)] = result.db.loadArchived(uint16(h))

        #Reload the signatures.
        result.signatures[uint16(h)] = @[]
        try:
            for n in result.archived[uint16(h)] + 1 .. result.db.load(uint16(h)):
                result.signatures[uint16(h)].add(result.db.loadSignature(uint16(h), n))
        except KeyError as e:
            doAssert(false, "Couldn't add a signature to the signature cache of a holder we just added: " & e.msg)
        except DBReadError as e:
            doAssert(false, "Couldn't load a signature we know we have: " & e.msg)

    #Load statuses still in Epochs.
    #Just like Epochs, this first requires loading the old last 5 Blocks and then the current last 5 Blocks.
    var
        height: int = functions.merit.getHeight()
        old: HashSet[Hash[256]] = initHashSet[Hash[256]]()
    try:
        for i in max(height - 10, 0) ..< height - 5:
            for packet in functions.merit.getBlockByNonce(i).body.packets:
                old.incl(packet.hash)

        for i in max(height - 5, 0) ..< height:
            #Skip old Transactions.
            for packet in functions.merit.getBlockByNonce(i).body.packets:
                if old.contains(packet.hash):
                    continue

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

    #Load unmentioned Transactions.
    var unmentioned: seq[Hash[256]] = result.db.loadUnmentioned()
    for hash in unmentioned:
        result.unmentioned.incl(hash)

#Set a Transaction as unmentioned.
proc setUnmentioned*(
    consensus: Consensus,
    hash: Hash[256]
) {.forceCheck: [].} =
    consensus.unmentioned.incl(hash)

#Set a Transaction's status.
proc setStatus*(
    consensus: Consensus,
    hash: Hash[256],
    status: TransactionStatus
) {.forceCheck: [].} =
    consensus.statuses[hash] = status
    consensus.db.save(hash, status)

#Get a Transaction's statuses.
proc getStatus*(
    consensus: Consensus,
    hash: Hash[256]
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
    hash: Hash[256]
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
    hash: Hash[256],
    statusArg: TransactionStatus
) {.forceCheck: [].} =
    var
        children: seq[Hash[256]] = @[hash]
        child: Hash[256]
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
                    var spenders: seq[Hash[256]] = consensus.functions.transactions.getSpenders(newFundedInput(child, o))
                    for spender in spenders:
                        children.add(spender)
            except IndexError as e:
                doAssert(false, "Couldn't get a child Transaction/child Transaction's Status we've marked as a spender of this Transaction: " & e.msg)

#Unverify a Transaction.
proc unverify*(
    consensus: Consensus,
    state: State,
    hash: Hash[256],
    status: TransactionStatus
) {.forceCheck: [].} =
    var
        children: seq[Hash[256]] = @[hash]
        child: Hash[256]
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
        #Children of Transactions which aren't verified can't be verified and therefore can be skipped.
        if childStatus.verified:
            echo "Verified Transaction was unverified: ", child
            childStatus.verified = false
            consensus.db.save(child, childStatus)

            try:
                for o in 0 ..< tx.outputs.len:
                    var spenders: seq[Hash[256]] = consensus.functions.transactions.getSpenders(newFundedInput(child, o))
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
    hash: Hash[256],
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
            var spenders: seq[Hash[256]] = consensus.functions.transactions.getSpenders(input)
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

#Get all pending Verification Packets/Elements, as well as the aggregate signature.
proc getPending*(
    consensus: Consensus
): tuple[
    packets: seq[SignedVerificationPacket],
    elements: seq[BlockElement],
    aggregate: BLSSignature
] {.forceCheck: [].} =
    var included: HashSet[Hash[256]] = initHashSet[Hash[256]]()
    for status in consensus.statuses.values():
        if status.pending.holders.len != 0:
            result.packets.add(status.pending)
            included.incl(status.pending.hash)

    var signatures: seq[BLSSignature] = @[]
    try:
        for holder in consensus.signatures.keys():
            if consensus.malicious.hasKey(holder):
                result.elements.add(consensus.malicious[holder][0])
                signatures.add(consensus.malicious[holder][0].signature)
                continue

            if consensus.signatures[holder].len != 0:
                var nonce: int = consensus.archived[holder] + 1
                for s in 0 ..< consensus.signatures[holder].len:
                    result.elements.add(consensus.db.load(holder, nonce + s))
                    signatures.add(consensus.signatures[holder][s])
    except KeyError as e:
        doAssert(false, "Couldn't get the nonce/signatures/MeritRemoval of a holder we know we have: " & e.msg)
    except DBReadError as e:
        doAssert(false, "Couldn't get an Element we know we have: " & e.msg)

    var p: int = 0
    while p < result.packets.len:
        var
            tx: Transaction
            mentioned: bool

        try:
            tx = consensus.functions.transactions.getTransaction(result.packets[p].hash)
        except IndexError as e:
            doAssert(false, "Couldn't get a Transaction which has a packet: " & e.msg)

        block checkPredecessors:
            if tx of Claim:
                break checkPredecessors
            if (tx of Data) and (tx.inputs[0].hash == Hash[256]()):
                break checkPredecessors

            for input in tx.inputs:
                var status: TransactionStatus
                try:
                    status = consensus.getStatus(input.hash)
                except IndexError as e:
                    doAssert(false, "Couldn't get the status of a Transaction before the current Transaction: " & e.msg)

                mentioned = included.contains(input.hash) or ((status.holders.len != 0) and (not consensus.unmentioned.contains(input.hash)))
                if not mentioned:
                    break

            if not mentioned:
                result.packets.del(p)
                continue

        signatures.add(result.packets[p].signature)
        inc(p)

    result.aggregate = signatures.aggregate()

#Provide debug access to the statuses table
when defined(merosTests):
    func statuses*(
        consensus: Consensus
    ): Table[Hash[256], TransactionStatus] {.inline, forceCheck: [].} =
        consensus.statuses
