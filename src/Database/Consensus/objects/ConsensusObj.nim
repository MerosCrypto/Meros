#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Consensus DB lib.
import ../../Filesystem/DB/ConsensusDB

#ConsensusIndex object.
import ../../common/objects/ConsensusIndexObj

#Element objects.
import ElementObj
import VerificationObj
import MeritRemovalObj

#TransactionStatus object.
import TransactionStatusObj
export TransactionStatusObj

#State lib.
import ../../Merit/State

#SpamFilter object.
import SpamFilterObj

#MeritHolder object.
import MeritHolderObj

#Tables standard lib.
import tables

#Finals lib.
import finals

#Consensus object.
type Consensus* = ref object
    #DB.
    db*: DB

    #Filters.
    filters*: tuple[send: SpamFilter, data: SpamFilter]

    #BLS Public Key -> MeritHolder.
    holders: Table[string, MeritHolder]
    #BLS Public Key -> MeritRemoval.
    malicious*: Table[string, seq[MeritRemoval]]

    #Statuses of Transactions not yet out of Epochs.
    statuses*: Table[string, TransactionStatus]
    #Verifications of unknown Transactions.
    unknowns*: Table[string, seq[BLSPublicKey]]

#Consensus constructor.
proc newConsensusObj*(
    db: DB,
    sendDiff: Hash[384],
    dataDiff: Hash[384]
): Consensus {.forceCheck: [].} =
    #Create the Consensus object.
    result = Consensus(
        db: db,

        filters: (
            send: newSpamFilterObj(sendDiff),
            data: newSpamFilterObj(dataDiff)
        ),

        holders: initTable[string, MeritHolder](),
        malicious: initTable[string, seq[MeritRemoval]](),

        statuses: initTable[string, TransactionStatus](),
        unknowns: initTable[string, seq[BLSPublicKey]]()
    )

    #Grab the MeritHolders, if any exist.
    var holders: seq[string]
    try:
        holders = result.db.loadHolders()
    #If none exist, return.
    except DBReadError:
        return

    #Load each MeritHolder.
    for holder in holders:
        try:
            result.holders[holder] = newMeritHolderObj(result.db, newBLSPublicKey(holder))
        except BLSError as e:
            doAssert(false, "Couldn't create a BLS Public Key for a known MeritHolder: " & e.msg)

#Creates a new MeritHolder on the Consensus.
proc add(
    consensus: Consensus,
    holder: BLSPublicKey
) {.forceCheck: [].} =
    #Create a string of the holder.
    var holderStr: string = holder.toString()

    #Make sure the holder doesn't already exist.
    if consensus.holders.hasKey(holderStr):
        return

    #Create a new MeritHolder.
    consensus.holders[holderStr] = newMeritHolderObj(consensus.db, holder)

    #Add the MeritHolder to the DB.
    try:
        consensus.db.save(holder, consensus.holders[holderStr].archived)
    except KeyError as e:
        doAssert(false, "Couldn't get a newly created MeritHolder's archived: " & e.msg)

#Calculate a Transaction's Merit.
proc calculateMerit*(
    consensus: Consensus,
    state: var State,
    status: TransactionStatus
) {.forceCheck: [].} =
    var merit: int = 0
    for verifier in status.verifiers:
        #Skip malicious MeritHolders from Merit calculations.
        if not consensus.malicious.hasKey(verifier.toString()):
            merit += state[verifier]

    #Check if the Transaction crossed its threshold, as long as it doesn't need to default.
    if (not status.defaulting) and (merit >= state.nodeThresholdAt(status.epoch)):
        status.verified = true

#Update a Status with a new verifier.
proc update*(
    consensus: Consensus,
    state: var State,
    hash: Hash[384],
    verifier: BLSPublicKey
) {.forceCheck: [].} =
    #Grab the status.
    var status: TransactionStatus
    try:
        status = consensus.statuses[hash.toString()]
    except KeyError:
        doAssert(false, "Transaction was either not registered or is out of Epochs.")

    #Add the Verifier.
    status.verifiers.add(verifier)

    #Calculate Merit.
    consensus.calculateMerit(state, status)

#Gets a MeritHolder by their key.
proc `[]`*(
    consensus: Consensus,
    holder: BLSPublicKey
): var MeritHolder {.forceCheck: [].} =
    #Call add, which will only create a new MeritHolder if one doesn't exist.
    consensus.add(holder)

    #Return the holder.
    try:
        result = consensus.holders[holder.toString()]
    except KeyError as e:
        doAssert(false, "Couldn't grab a MeritHolder despite just calling `add` for that MeritHolder: " & e.msg)

#Gets a Element by its Index.
proc `[]`*(
    consensus: Consensus,
    index: ConsensusIndex
): Element {.forceCheck: [IndexError].} =
    #Check the nonce isn't out of bounds.
    if consensus[index.key].height <= index.nonce:
        raise newException(IndexError, "MeritHolder doesn't have an Element for that nonce.")

    try:
        result = consensus.holders[index.key.toString()][index.nonce]
    except KeyError as e:
        doAssert(false, "Couldn't grab a MeritHolder despite just calling `add` for that MeritHolder: " & e.msg)
    except IndexError as e:
        fcRaise e

#Iterate over every MeritHolder.
iterator holders*(
    consensus: Consensus
): BLSPublicKey {.raises: [].} =
    for holder in consensus.holders.keys():
        try:
            yield consensus.holders[holder].key
        except KeyError as e:
            doAssert(false, "Couldn't grab a MeritHolder despite only asking for it because of the keys iterator: " & e.msg)
