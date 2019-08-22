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
import ../../../Network/Serialize/SerializeCommon

import Serialize/Merit/SerializeDifficulty
import Serialize/Merit/DBSerializeBlock

import Serialize/Merit/ParseDifficulty
import Serialize/Merit/DBParseBlockHeader
import Serialize/Merit/DBParseBlock

#DB object.
import objects/DBObj
export DBObj

#Tables standard lib.
import tables

#Put/Get/Commit for the Merit DB.
proc put(
    db: DB,
    key: string,
    val: string
) {.forceCheck: [].} =
    db.merit.cache[key] = val

proc get(
    db: DB,
    key: string
): string {.forceCheck: [
    DBReadError
].} =
    if db.merit.cache.hasKey(key):
        try:
            return db.merit.cache[key]
        except KeyError as e:
            doAssert(false, "Couldn't get a key from a table confirmed to exist: " & e.msg)

    try:
        result = db.lmdb.get("merit", key)
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc commit*(
    db: DB,
    blockNum: int
) {.forceCheck: [].} =
    var items: seq[tuple[key: string, value: string]] = newSeq[tuple[key: string, value: string]](db.merit.cache.len)
    try:
        var i: int = 0
        for key in db.merit.cache.keys():
            items[i] = (key: key, value: db.merit.cache[key])
            inc(i)
    except KeyError as e:
        doAssert(false, "Couldn't get a value from the table despiting getting the key from .keys(): " & e.msg)

    var removals: string = ""
    try:
        for key in db.merit.removals.keys():
            removals &= key & db.merit.removals[key].toBinary().pad(INT_LEN)
    except KeyError as e:
        doAssert(false, "Couldn't get a value from the table despiting getting the key from .keys(): " & e.msg)
    if removals != "":
        items.add((key: "removals" & blockNum.toBinary(), value: removals))
        db.merit.removals = initTable[string, int]()

    try:
        db.lmdb.put("merit", items)
    except Exception as e:
        doAssert(false, "Couldn't save data to the Database: " & e.msg)

    db.merit.cache = initTable[string, string]()

#Save functions.
proc save*(
    db: DB,
    difficulty: Difficulty
) {.forceCheck: [].} =
    db.put("difficulty", difficulty.serialize())

proc save*(
    db: DB,
    blockArg: Block
) {.forceCheck: [].} =
    db.put(blockArg.hash.toString(), blockArg.serialize())

proc saveTip*(
    db: DB,
    hash: Hash[384]
) {.forceCheck: [].} =
    db.put("tip", hash.toString())

proc saveLiveMerit*(
    db: DB,
    merit: int
) {.forceCheck: [].} =
    db.put("merit", merit.toBinary())

proc save*(
    db: DB,
    holder: string,
    merit: int
) {.forceCheck: [].} =
    if not db.merit.holders.hasKey(holder):
        db.merit.holders[holder] = true
        db.merit.holdersStr &= holder
        db.put("holders", db.merit.holdersStr)

    db.put(holder, merit.toBinary())

proc remove*(
    db: DB,
    holder: string,
    merit: int,
    blockNum: int
) {.forceCheck: [].} =
    db.merit.removals[holder] = merit

    #The following (individual holder's removals) hould be loaded on boot and then kept in RAM, for every holder.
    var holderRemovals: string
    try:
        holderRemovals = db.get(holder & "removals")
    except DBReadError:
        holderRemovals = ""

    db.put(holder & "removals", holderRemovals & blockNum.toBinary().pad(4))

proc saveHolderEpoch*(
    db: DB,
    holder: BLSPublicKey,
    epoch: int
) {.forceCheck: [].} =
    db.put(holder.toString() & "epoch", epoch.toBinary())

#Load functions.
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
    except DBReadError as e:
        fcRaise e

proc loadHolders*(
    db: DB
): seq[string] {.forceCheck: [
    DBReadError
].} =
    try:
        db.merit.holdersStr = db.get("holders")
    except DBReadError as e:
        fcRaise e

    result = newSeq[string](db.merit.holdersStr.len div 48)
    for i in countup(0, db.merit.holdersStr.len - 1, 48):
        result[i div 48] = db.merit.holdersStr[i ..< i + 48]
        db.merit.holders[db.merit.holdersStr[i ..< i + 48]] = true

proc loadMerit*(
    db: DB,
    holder: string
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(holder).fromBinary()
    except DBReadError as e:
        fcRaise e

proc loadRemovals*(
    db: DB,
    blockNum: int
): string {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get("removals" & blockNum.toBinary())
    except DBReadError as e:
        fcRaise e

proc loadRemovals*(
    db: DB,
    holder: BLSPublicKey
): string {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(holder.toString() & "removals")
    except DBReadError as e:
        fcRaise e

proc loadHolderEpoch*(
    db: DB,
    holder: string
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(holder & "epoch").fromBinary()
    except DBReadError as e:
        fcRaise e
