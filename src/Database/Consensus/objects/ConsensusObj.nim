#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Consensus DB lib.
import ../../Filesystem/DB/ConsensusDB

#ConsensusIndex object.
import ../../common/objects/ConsensusIndexObj

#Verification object.
import VerificationObj

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
    #List of every MeritHolder.
    holdersStr: string

    #MeritHolder -> Account.
    holders: TableRef[string, MeritHolder]

#Consensus constructor.
proc newConsensusObj*(
    db: DB
): Consensus {.forceCheck: [].} =
    #Create the Consensus object.
    result = Consensus(
        db: db,
        holders: newTable[string, MeritHolder]()
    )

    #Grab the MeritHolders' string, if it exists.
    try:
        result.holdersStr = result.db.get("consensus_holders")
    #If it doesn't, set the MeritHolders' string to "",
    except DBReadError:
        result.holdersStr = ""

    #Create a MeritHolder for each one in the string.
    for i in countup(0, result.holdersStr.len - 1, 48):
        #Extract the holder.
        var holder: string = result.holdersStr[i ..< i + 48]

        #Load the MeritHolder.
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

    #Add the MeritHolder to the MeritHolder's string.
    consensus.holdersStr &= holderStr
    #Update the MeritHolder's String in the DB.
    try:
        consensus.db.put("consensus_holders", consensus.holdersStr)
    except DBWriteError as e:
        doAssert(false, "Couldn't update the MeritHolders' string: " & e.msg)

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

#Gets a Verification by its Index.
proc `[]`*(
    consensus: Consensus,
    index: ConsensusIndex
): Verification {.forceCheck: [IndexError].} =
    #Check the nonce isn't out of bounds.
    if consensus[index.key].height <= index.nonce:
        raise newException(IndexError, "MeritHolder doesn't have a Verification for that nonce.")

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
