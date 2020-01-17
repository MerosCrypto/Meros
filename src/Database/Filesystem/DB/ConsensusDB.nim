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

#Key generators.
template STATUS(
    hash: Hash[256]
): string =
    hash.toString()

template UNMENTIONED(): string =
    "u"

template HOLDER_NONCE(
    holder: uint16
): string =
    holder.toBinary(NICKNAME_LEN)

template HOLDER_ARCHIVED_NONCE(
    holder: uint16
): string =
    holder.toBinary(NICKNAME_LEN) & "a"

template HOLDER_SEND_DIFFICULTY(
    holder: uint16
): string =
    holder.toBinary(NICKNAME_LEN) & "s"

template HOLDER_DATA_DIFFICULTY(
    holder: uint16
): string =
    holder.toBinary(NICKNAME_LEN) & "d"

template BLOCK_ELEMENT(
    holder: uint16,
    nonce: int
): string =
    holder.toBinary(NICKNAME_LEN) & nonce.toBinary(INT_LEN)

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
    items[^1] = (key: UNMENTIONED(), value: db.consensus.unmentioned)
    db.consensus.unmentioned = ""

    try:
        db.lmdb.put("consensus", items)
    except Exception as e:
        doAssert(false, "Couldn't save data to the Database: " & e.msg)

    db.consensus.cache = initTable[string, string]()

#Save functions.
proc save*(
    db: DB,
    hash: Hash[256],
    status: TransactionStatus
) {.inline, forceCheck: [].} =
    db.put(STATUS(hash), status.serialize())

proc addUnmentioned*(
    db: DB,
    unmentioned: Hash[256]
) {.inline, forceCheck: [].} =
    db.consensus.unmentioned &= unmentioned.toString()

proc save*(
    db: DB,
    sendDiff: SendDifficulty
) {.forceCheck: [].} =
    db.put(HOLDER_NONCE(sendDiff.holder), sendDiff.nonce.toBinary())
    db.put(HOLDER_SEND_DIFFICULTY(sendDiff.holder), sendDiff.difficulty.toString())

    db.put(
        BLOCK_ELEMENT(sendDiff.holder, sendDiff.nonce),
        char(SEND_DIFFICULTY_PREFIX) & sendDiff.difficulty.toString()
    )

proc save*(
    db: DB,
    dataDiff: DataDifficulty
) {.forceCheck: [].} =
    db.put(HOLDER_NONCE(dataDiff.holder), dataDiff.nonce.toBinary())
    db.put(HOLDER_DATA_DIFFICULTY(dataDiff.holder), dataDiff.difficulty.toString())

    db.put(
        BLOCK_ELEMENT(dataDiff.holder, dataDiff.nonce),
        char(DATA_DIFFICULTY_PREFIX) & dataDiff.difficulty.toString()
    )

proc saveArchived*(
    db: DB,
    holder: uint16,
    nonce: int
) {.inline, forceCheck: [].} =
    db.put(HOLDER_ARCHIVED_NONCE(holder), nonce.toBinary())

#Load functions.
proc load*(
    db: DB,
    hash: Hash[256]
): TransactionStatus {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(STATUS(hash)).parseTransactionStatus(hash)
    except DBReadError as e:
        raise e

proc loadUnmentioned*(
    db: DB
): seq[Hash[256]] {.forceCheck: [].} =
    var unmentioned: string
    try:
        unmentioned = db.get(UNMENTIONED())
    except DBReadError:
        return @[]

    result = newSeq[Hash[256]](unmentioned.len div 32)
    for i in countup(0, unmentioned.len - 1, 32):
        try:
            result[i div 32] = unmentioned[i ..< i + 32].toHash(256)
        except ValueError as e:
            doAssert(false, "Couldn't parse an unmentioned hash: " & e.msg)

proc load*(
    db: DB,
    holder: uint16
): int {.forceCheck: [].} =
    try:
        result = db.get(HOLDER_NONCE(holder)).fromBinary()
    except DBReadError:
        result = -1

proc loadSendDifficulty*(
    db: DB,
    holder: uint16
): Hash[256] {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(HOLDER_SEND_DIFFICULTY(holder)).toHash(256)
    except ValueError:
        doAssert(false, "Couldn't turn a 32-byte value into a 32-byte hash.")
    except DBReadError as e:
        raise e

proc loadDataDifficulty*(
    db: DB,
    holder: uint16
): Hash[256] {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(HOLDER_DATA_DIFFICULTY(holder)).toHash(256)
    except ValueError:
        doAssert(false, "Couldn't turn a 32-byte value into a 32-byte hash.")
    except DBReadError as e:
        raise e

proc load*(
    db: DB,
    holder: uint16,
    nonce: int
): BlockElement {.forceCheck: [
    DBReadError
].} =
    var elem: string
    try:
        elem = db.get(BLOCK_ELEMENT(holder, nonce))
    except DBReadError as e:
        fcRaise e

    try:
        case int(elem[0]):
            of SEND_DIFFICULTY_PREFIX:
                result = newSendDifficultyObj(nonce, elem[1 ..< 33].toHash(256))
                result.holder = holder
            of DATA_DIFFICULTY_PREFIX:
                result = newDataDifficultyObj(nonce, elem[1 ..< 33].toHash(256))
                result.holder = holder
            else:
                doAssert(false, "Tried to load an unknown Block Element: " & $int(elem[0]))
    except ValueError:
        doAssert(false, "Couldn't convert a 32-byte value to a 32-byte hash.")

proc loadArchived*(
    db: DB,
    holder: uint16
): int {.forceCheck: [].} =
    try:
        result = db.get(HOLDER_ARCHIVED_NONCE(holder)).fromBinary()
    except DBReadeRROR:
        result = 0
