#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Verification object.
import ../../Consensus/objects/VerificationObj

#DB object.
import objects/DBObj
export DBObj

#Tables standard lib.
import tables

#Put/Get for the Consensus DB.
proc put(
    db: DB,
    key: string,
    val: string
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.lmdb.put("consensus", key, val)
    except Exception as e:
        raise newException(DBWriteError, e.msg)

proc get(
    db: DB,
    key: string
): string {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.lmdb.get("consensus", key)
    except Exception as e:
        raise newException(DBReadError, e.msg)

#Save functions.
proc save*(
    db: DB,
    holder: BLSPublicKey,
    epoch: int
) {.forceCheck: [
    DBWriteError
].} =
    var holderStr: string = holder.toString()

    try:
        discard db.consensus.holders[holderStr]
    except KeyError:
        db.consensus.holders[holderStr] = true
        db.consensus.holdersStr &= holderStr
        try:
            db.put("holders", db.consensus.holdersStr)
        except DBWriteError as e:
            fcRaise e

    try:
        db.put(holderStr, $epoch)
    except DBWriteError as e:
        fcRaise e

proc save*(
    db: DB,
    verif: Verification
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.put(verif.holder.toString() & verif.nonce.toBinary().pad(1), verif.hash.toString())
    except DBWriteError as e:
        fcRaise e

proc loadHolders*(
    db: DB
): seq[string] {.forceCheck: [
    DBReadError
].} =
    var holders: string
    try:
        holders = db.get("holders")
    except Exception as e:
        raise newException(DBReadError, e.msg)

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

proc commit*(
    db: DB
) {.forceCheck: [].} =
    discard
