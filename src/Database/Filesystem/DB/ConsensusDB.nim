#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Verification object.
import ../../Consensus/objects/ElementObj
import ../../Consensus/objects/SendDifficultyObj
import ../../Consensus/objects/VerificationObj
import ../../Consensus/objects/DataDifficultyObj
import ../../Consensus/objects/GasPriceObj
import ../../Consensus/objects/MeritRemovalObj

#DB object.
import objects/DBObj
export DBObj

#Tables standard lib.
import tables

#Put/Get/Commit for the Consensus DB.
proc put(
    db: DB,
    key: string,
    val: string
) {.forceCheck: [].} =
    db.consensus.cache[key] = val

proc get(
    db: DB,
    key: string
): string {.forceCheck: [
    DBReadError
].} =
    if db.consensus.cache.hasKey(key):
        try:
            return db.consensus.cache[key]
        except KeyError as e:
            doAssert(false, "Couldn't get a key from a table confirmed to exist: " & e.msg)

    try:
        result = db.lmdb.get("consensus", key)
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc commit*(
    db: DB
) {.forceCheck: [].} =
    for key in db.consensus.cache.keys():
        try:
            db.lmdb.put("consensus", key, db.consensus.cache[key])
        except KeyError as e:
            doAssert(false, "Couldn't get a value from the table despiting getting the key from .keys(): " & e.msg)
        except Exception as e:
            doAssert(false, "Couldn't save data to the Database: " & e.msg)
    db.consensus.cache = initTable[string, string]()

#Save functions.
proc save*(
    db: DB,
    holder: BLSPublicKey,
    epoch: int
) {.forceCheck: [].} =
    var holderStr: string = holder.toString()

    try:
        discard db.consensus.holders[holderStr]
    except KeyError:
        db.consensus.holders[holderStr] = true
        db.consensus.holdersStr &= holderStr
        db.put("holders", db.consensus.holdersStr)

    db.put(holderStr, $epoch)

proc save*(
    db: DB,
    element: Element
) {.forceCheck: [].} =

    # stubs
    if element of SendDifficulty:
        discard
    elif element of Verification:
        db.put(
            element.holder.toString() & element.nonce.toBinary().pad(1),
            cast[Verification](element).hash.toString()
        )
    elif element of DataDifficulty:
        discard
    elif element of GasPrice:
        discard
    elif element of MeritRemovalObj.MeritRemoval:
        discard


proc loadHolders*(
    db: DB
): seq[string] {.forceCheck: [
    DBReadError
].} =
    var holders: string
    try:
        holders = db.get("holders")
    except DBReadError as e:
        fcRaise e
    
    result = newSeq[string](holders.len div 48)
    for i in countup(0, holders.len - 1, 48):
        result[i div 48] = holders[i ..< i + 48]

proc load*(
    db: DB,
    holder: BLSPublicKey
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = parseInt(db.get(holder.toString()))
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc load*(
    db: DB,
    holder: BLSPublicKey,
    nonce: int
): Verification {.forceCheck: [
    DBReadError
].} =
    try:
        result = newVerificationObj(
            db.get(holder.toString() & nonce.toBinary().pad(1)).toHash(384)
        )
        result.holder = holder
        result.nonce = nonce
    except Exception as e:
        raise newException(DBReadError, e.msg)
