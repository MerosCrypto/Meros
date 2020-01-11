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

const BLOCK_REMOVAL_LEN: int = NICKNAME_LEN + INT_LEN

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
    height: int
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
        for nick in db.merit.removals.keys():
            removals &= nick.toBinary(NICKNAME_LEN) & db.merit.removals[nick].toBinary(INT_LEN)
    except KeyError as e:
        doAssert(false, "Couldn't get a value from the table despiting getting the key from .keys(): " & e.msg)
    if removals != "":
        items.add((key: "removals" & (height - 1).toBinary(), value: removals))
        db.merit.removals = initTable[uint16, int]()

    try:
        db.lmdb.put("merit", items)
    except Exception as e:
        doAssert(false, "Couldn't save data to the Database: " & e.msg)

    db.merit.cache = initTable[string, string]()

#Save functions.
proc saveHeight*(
    db: DB,
    height: int
) {.forceCheck: [].} =
    db.put("height", height.toBinary())

proc saveTip*(
    db: DB,
    hash: Hash[256]
) {.forceCheck: [].} =
    db.put("tip", hash.toString())

proc save*(
    db: DB,
    nonce: int,
    blockArg: Block
) {.forceCheck: [].} =
    db.put(blockArg.header.hash.toString(), blockArg.serialize())
    db.put("n" & nonce.toBinary(), blockArg.header.hash.toString())

proc saveUpcomingKey*(
    db: DB,
    key: string
) {.forceCheck: [].} =
    db.put("upcoming", key)

proc saveKey*(
    db: DB,
    key: string
) {.forceCheck: [].} =
    db.put("key", key)

proc save*(
    db: DB,
    difficulty: Difficulty
) {.forceCheck: [].} =
    db.put("difficulty", difficulty.serialize())

proc saveUnlocked*(
    db: DB,
    blockNum: int,
    merit: int
) {.forceCheck: [].} =
    db.put("merit" & blockNum.toBinary(), merit.toBinary())

proc saveHolder*(
    db: DB,
    key: BLSPublicKey
) {.forceCheck: [].} =
    db.put(key.serialize(), (db.merit.holders.len div BLS_PUBLIC_KEY_LEN).toBinary())
    db.merit.holders = db.merit.holders & key.serialize()
    db.put("holders", db.merit.holders)

proc saveMerit*(
    db: DB,
    nick: uint16,
    merit: int
) {.forceCheck: [].} =
    db.put("h" & nick.toBinary(), merit.toBinary())

proc remove*(
    db: DB,
    nick: uint16,
    merit: int,
    blockNum: int
) {.forceCheck: [].} =
    db.merit.removals[nick] = merit

    var
        nickStr: string = nick.toBinary(BYTE_LEN)
        removals: string
    try:
        removals = db.get(nickStr & "removals")
    except DBReadError:
        removals = ""

    db.put(nickStr & "removals", removals & blockNum.toBinary(INT_LEN))

#Load functions.
proc loadHeight*(
    db: DB
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get("height").fromBinary()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadTip*(
    db: DB
): Hash[256] {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get("tip").toHash(256)
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadBlockHeader*(
    db: DB,
    hash: Hash[256]
): BlockHeader {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(hash.toString()).parseBlockHeader(hash)
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadBlock*(
    db: DB,
    hash: Hash[256]
): Block {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(hash.toString()).parseBlock()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadBlock*(
    db: DB,
    nonce: int
): Block {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(db.get("n" & nonce.toBinary())).parseBlock()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadUpcomingKey*(
    db: DB
): string {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get("upcoming")
    except DBReadError as e:
        raise e

proc loadKey*(
    db: DB
): string {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get("key")
    except DBReadError as e:
        raise e

proc loadDifficulty*(
    db: DB
): Difficulty {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get("difficulty").parseDifficulty()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadUnlocked*(
    db: DB,
    blockNum: int
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get("merit" & blockNum.toBinary()).fromBinary()
    except DBReadError as e:
        raise e

proc loadHolders*(
    db: DB
): seq[BLSPublicKey] {.forceCheck: [].} =
    try:
        db.merit.holders = db.get("holders")
    except DBReadError:
        return @[]

    result = newSeq[BLSPublicKey](db.merit.holders.len div BLS_PUBLIC_KEY_LEN)
    for i in countup(0, db.merit.holders.len - 1, BLS_PUBLIC_KEY_LEN):
        try:
            result[i div BLS_PUBLIC_KEY_LEN] = newBLSPublicKey(db.merit.holders[i ..< i + BLS_PUBLIC_KEY_LEN])
        except BLSError as e:
            doAssert(false, "Couldn't load a holder's BLS Public Key: " & e.msg)

proc loadMerit*(
    db: DB,
    nick: uint16
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get("h" & nick.toBinary()).fromBinary()
    except DBReadError as e:
        raise e

proc loadBlockRemovals*(
    db: DB,
    blockNum: int
): seq[tuple[nick: uint16, merit: int]] {.forceCheck: [].} =
    var removals: string
    try:
        removals = db.get("removals" & blockNum.toBinary(BYTE_LEN))
    except DBReadError:
        return @[]

    for i in countup(0, removals.len - 1, NICKNAME_LEN + INT_LEN):
        result.add(
            (
                nick: uint16(removals[i ..< i + NICKNAME_LEN].fromBinary()),
                merit: removals[i + NICKNAME_LEN ..< i + BLOCK_REMOVAL_LEN].fromBinary()
            )
        )

proc loadHolderRemovals*(
    db: DB,
    nick: uint16
): seq[int] {.forceCheck: [].} =
    var removals: string
    try:
        removals = db.get(nick.toBinary(BYTE_LEN) & "removals")
    except DBReadError:
        return @[]

    for i in countup(0, removals.len - 1, 4):
        result.add(removals[i ..< i + 4].fromBinary())

proc loadNickname*(
    db: DB,
    key: BLSPublicKey
): uint16 {.forceCheck: [
    DBReadError
].} =
    try:
        result = uint16(db.get(key.serialize()).fromBinary())
    except DBReadError as e:
        raise e

#Check if a Block exists.
proc hasBlock*(
    db: DB,
    hash: Hash[256]
): bool {.forceCheck: [].} =
    try:
        discard db.get(hash.toString())
        return true
    except DBReadError:
        return false
