#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Difficulty, BlockHeader, and Block objects.
import ../../Merit/objects/DifficultyObj
import ../../Merit/objects/BlockHeaderObj
import ../../Merit/objects/BlockObj

#Serialization libs.
import Serialize/Merit/SerializeDifficulty
import Serialize/Merit/SerializeBlock

import Serialize/Merit/ParseDifficulty
import Serialize/Merit/ParseBlockHeader
import Serialize/Merit/ParseBlock

#DB object.
import objects/DBObj
export DBObj

#Put/Get for the Merit DB.
proc put(
    db: DB,
    key: string,
    val: string
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.lmdb.put("merit", key, val)
    except Exception as e:
        raise newException(DBWriteError, e.msg)

proc get(
    db: DB,
    key: string
): string {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.lmdb.get("merit", key)
    except Exception as e:
        raise newException(DBReadError, e.msg)

#Save functions.
proc save*(
    db: DB,
    difficulty: Difficulty
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.put("difficulty", difficulty.serialize())
    except DBWriteError as e:
        fcRaise e

proc save*(
    db: DB,
    blockArg: Block
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.put(blockArg.hash.toString(), blockArg.serialize())
    except DBWriteError as e:
        fcRaise e

proc saveTip*(
    db: DB,
    hash: Hash[384]
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.put("tip", hash.toString())
    except DBWriteError as e:
        fcRaise e

proc saveLiveMerit*(
    db: DB,
    merit: int
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.put("merit", merit.toBinary())
    except DBWriteError as e:
        fcRaise e

proc save*(
    db: DB,
    holder: string,
    merit: int
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.put(holder, merit.toBinary())
    except DBWriteError as e:
        fcRaise e

proc saveHolderEpoch*(
    db: DB,
    holder: BLSPublicKey,
    epoch: int
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.put(holder.toString() & "_epoch", epoch.toBinary())
    except DBWriteError as e:
        fcRaise e

proc loadDifficulty*(
    db: DB
): Difficulty {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get("difficulty").parseDifficulty()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadBlockHeader*(
    db: DB,
    hash: Hash[384]
): BlockHeader {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(hash.toString()).substr(0, BLOCK_HEADER_LEN - 1).parseBlockHeader()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadBlock*(
    db: DB,
    hash: Hash[384]
): Block {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(hash.toString()).parseBlock()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadTip*(
    db: DB
): Hash[384] {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get("tip").toHash(384)
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadLiveMerit*(
    db: DB
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get("merit").fromBinary()
    except Exception as e:
        raise newException(DBReadError, e.msg)

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

proc loadMerit*(
    db: DB,
    holder: string
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(holder).fromBinary()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadHolderEpoch*(
    db: DB,
    holder: string
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(holder & "_epoch").fromBinary()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc commit*(
    db: DB
) {.forceCheck: [].} =
    discard
