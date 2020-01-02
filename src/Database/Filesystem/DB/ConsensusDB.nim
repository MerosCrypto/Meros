#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Difficulty objects.
import ../../Consensus/Elements/objects/SendDifficultyObj
import ../../Consensus/Elements/objects/DataDifficultyObj

#TransactionStatus object.
import ../../Consensus/objects/TransactionStatusObj

#Serialization libs.
import ../../../Network/Serialize/SerializeCommon

import Serialize/Consensus/SerializeTransactionStatus
import Serialize/Consensus/ParseTransactionStatus

#DB object.
import objects/DBObj
export DBObj

#Tables standard lib.
import tables

#Put/Get/Delete/Commit for the Consensus DB.
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
    for key in db.consensus.deleted:
        try:
            db.lmdb.delete("consensus", key)
        except Exception:
            #If we delete something before it's committed, it'll throw.
            discard
    db.consensus.deleted = @[]

    var items: seq[tuple[key: string, value: string]] = newSeq[tuple[key: string, value: string]](db.consensus.cache.len + 1)
    try:
        var i: int = 0
        for key in db.consensus.cache.keys():
            items[i] = (key: key, value: db.consensus.cache[key])
            inc(i)
    except KeyError as e:
        doAssert(false, "Couldn't get a value from the table despiting getting the key from .keys(): " & e.msg)

    #Save the unmentioned hashes.
    items[^1] = (key: "unmentioned", value: db.consensus.unmentioned)
    db.consensus.unmentioned = ""

    try:
        db.lmdb.put("consensus", items)
    except Exception as e:
        doAssert(false, "Couldn't save data to the Database: " & e.msg)

    db.consensus.cache = initTable[string, string]()

#Save functions.
proc save*(
    db: DB,
    sendDiff: SendDifficulty
) {.forceCheck: [].} =
    db.put(sendDiff.holder.toBinary().pad(NICKNAME_LEN) & "s", sendDiff.difficulty.toString())
    db.put(sendDiff.holder.toBinary().pad(NICKNAME_LEN), sendDiff.nonce.toBinary())

proc save*(
    db: DB,
    dataDiff: DataDifficulty
) {.forceCheck: [].} =
    db.put(dataDiff.holder.toBinary().pad(NICKNAME_LEN) & "d", dataDiff.difficulty.toString())
    db.put(dataDiff.holder.toBinary().pad(NICKNAME_LEN), dataDiff.nonce.toBinary())

proc save*(
    db: DB,
    hash: Hash[384],
    status: TransactionStatus
) {.forceCheck: [].} =
    db.put(hash.toString(), status.serialize())

proc addUnmentioned*(
    db: DB,
    unmentioned: Hash[384]
) {.forceCheck: [].} =
    db.consensus.unmentioned &= unmentioned.toString()

#Load functions.
proc load*(
    db: DB,
    holder: uint16
): int {.forceCheck: [].} =
    try:
        result = db.get(holder.toBinary().pad(NICKNAME_LEN)).fromBinary()
    except DBReadError:
        result = -1

proc loadSendDifficulty*(
    db: DB,
    holder: uint16
): Hash[384] {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(holder.toBinary().pad(NICKNAME_LEN) & "s").toHash(384)
    except ValueError:
        doAssert(false, "Couldn't turn a 48-byte value into a 48-byte hash.")
    except DBReadError as e:
        raise e

proc loadDataDifficulty*(
    db: DB,
    holder: uint16
): Hash[384] {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(holder.toBinary().pad(NICKNAME_LEN) & "d").toHash(384)
    except ValueError:
        doAssert(false, "Couldn't turn a 48-byte value into a 48-byte hash.")
    except DBReadError as e:
        raise e

proc load*(
    db: DB,
    hash: Hash[384]
): TransactionStatus {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(hash.toString()).parseTransactionStatus(hash)
    except DBReadError as e:
        raise e

proc loadUnmentioned*(
    db: DB
): seq[Hash[384]] {.forceCheck: [].} =
    var unmentioned: string
    try:
        unmentioned = db.get("unmentioned")
    except DBReadError:
        return @[]

    result = newSeq[Hash[384]](unmentioned.len div 48)
    for i in countup(0, unmentioned.len - 1, 48):
        try:
            result[i div 48] = unmentioned[i ..< i + 48].toHash(384)
        except ValueError as e:
            doAssert(false, "Couldn't parse an unmentioned hash: " & e.msg)
