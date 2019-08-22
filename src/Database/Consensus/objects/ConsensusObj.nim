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

    #BLS Public Key -> MeritHolder.
    holders: Table[string, MeritHolder]
    #BLS Public Key -> MeritRemoval.
    malicious*: Table[string, seq[MeritRemoval]]

    #Verifications of unknown transactions.
    unknowns*: Table[string, seq[BLSPublicKey]]

#Consensus constructor.
proc newConsensusObj*(
    db: DB
): Consensus {.forceCheck: [].} =
    #Create the Consensus object.
    result = Consensus(
        db: db,
        holders: initTable[string, MeritHolder](),
        malicious: initTable[string, seq[MeritRemoval]](),
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
