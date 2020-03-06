#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Elements lib.
import ../../Consensus/Elements/Elements

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

#Sets standard lib.
import sets

#Key generators.
template RANDOMX_KEY(): string =
    "r"

template UPCOMING_RANDOMX_KEY(): string =
    "u"

template HEIGHT(): string =
    "h"

template TIP(): string =
    "t"

template HOLDERS(): string =
    "n" #"N"icks, since "h" is taken.

template TOTAL_UNLOCKED_MERIT(
    blockNum: int
): string =
    blockNum.toBinary(INT_LEN) & "m"

template INTERIM_HASH(
    hash: Hash[256]
): string =
    hash.toString() & "i"

template BLOCK_HASH(
    hash: Hash[256]
): string =
    hash.toString()

template BLOCK_NONCE(
    nonce: int
): string =
    nonce.toBinary(INT_LEN)

template DIFFICULTY(
    hash: Hash[256]
): string =
    hash.toString() & "d"

template HOLDER_NICK(
    nick: uint16
): string =
    nick.toBinary(NICKNAME_LEN)

template HOLDER_KEY(
    key: BLSPublicKey
): string =
    key.serialize()

template HOLDER_KEY(
    key: string
): string =
    key

template MERIT(
    nick: uint16
): string =
    nick.toBinary(NICKNAME_LEN) & "m"

template BLOCK_REMOVALS(
    blockNum: int
): string =
    blockNum.toBinary(INT_LEN) & "r"

template HOLDER_REMOVALS(
    nick: uint16
): string =
    nick.toBinary(NICKNAME_LEN) & "r"

#Put/Get/Commit for the Merit DB.
proc put(
    db: DB,
    key: string,
    val: string
) {.forceCheck: [].} =
    db.merit.cache[key] = val
    db.merit.deleted.excl(key)
    when defined(merosTests):
        db.merit.used.incl(key)

proc get(
    db: DB,
    key: string
): string {.forceCheck: [
    DBReadError
].} =
    if db.merit.deleted.contains(key):
        raise newLoggedException(DBReadError, "Key deleted.")

    if db.merit.cache.hasKey(key):
        try:
            return db.merit.cache[key]
        except KeyError as e:
            panic("Couldn't get a key from a table confirmed to exist: " & e.msg)

    try:
        result = db.lmdb.get("merit", key)
    except Exception as e:
        raise newLoggedException(DBReadError, e.msg)

proc del(
    db: DB,
    key: string
) {.forceCheck: [].} =
    db.merit.deleted.incl(key)
    db.merit.cache.del(key)
    when defined(merosTests):
        db.merit.used.excl(key)

proc commit*(
    db: DB,
    height: int
) {.forceCheck: [].} =
    for key in db.merit.deleted:
        try:
            db.lmdb.delete("merit", key)
        except Exception:
            #If we delete something before it's committed, it'll throw.
            discard
    db.merit.deleted = initHashSet[string]()

    var items: seq[tuple[key: string, value: string]] = newSeq[tuple[key: string, value: string]](db.merit.cache.len)
    try:
        var i: int = 0
        for key in db.merit.cache.keys():
            items[i] = (key: key, value: db.merit.cache[key])
            inc(i)
    except KeyError as e:
        panic("Couldn't get a value from the table despiting getting the key from .keys(): " & e.msg)

    var removals: string = ""
    try:
        for nick in db.merit.removals.keys():
            removals &= nick.toBinary(NICKNAME_LEN) & db.merit.removals[nick].toBinary(INT_LEN)
    except KeyError as e:
        panic("Couldn't get a value from the table despiting getting the key from .keys(): " & e.msg)
    if removals != "":
        items.add((key: BLOCK_REMOVALS(height - 1), value: removals))
        db.merit.removals = initTable[uint16, int]()

    try:
        db.lmdb.put("merit", items)
    except Exception as e:
        panic("Couldn't save data to the Database: " & e.msg)

    db.merit.cache = initTable[string, string]()

#Save functions.
proc saveUpcomingKey*(
    db: DB,
    key: string
) {.forceCheck: [].} =
    db.put(UPCOMING_RANDOMX_KEY(), key)

proc saveKey*(
    db: DB,
    key: string
) {.forceCheck: [].} =
    db.put(RANDOMX_KEY(), key)

proc saveHeight*(
    db: DB,
    height: int
) {.forceCheck: [].} =
    db.put(HEIGHT(), height.toBinary())

proc saveTip*(
    db: DB,
    hash: Hash[256]
) {.forceCheck: [].} =
    db.put(TIP(), hash.toString())

proc save*(
    db: DB,
    hash: Hash[256],
    difficulty: Difficulty
) {.forceCheck: [].} =
    db.put(DIFFICULTY(hash), difficulty.serialize())

proc saveUnlocked*(
    db: DB,
    blockNum: int,
    merit: int
) {.forceCheck: [].} =
    db.put(TOTAL_UNLOCKED_MERIT(blockNum), merit.toBinary())

proc save*(
    db: DB,
    nonce: int,
    blockArg: Block
) {.forceCheck: [].} =
    db.put(INTERIM_HASH(blockArg.header.hash), blockArg.header.interimHash)
    db.put(BLOCK_HASH(blockArg.header.hash), blockArg.serialize())
    db.put(BLOCK_NONCE(nonce), blockArg.header.hash.toString())

proc saveHolder*(
    db: DB,
    key: BLSPublicKey
) {.forceCheck: [].} =
    var holders: uint16
    try:
        holders = uint16(db.get(HOLDERS()).fromBinary())
    except DBReadError:
        discard
    db.put(HOLDER_NICK(holders), key.serialize())
    db.put(HOLDER_KEY(key), holders.toBinary())
    db.put(HOLDERS(), (holders + 1).toBinary())

proc saveMerit*(
    db: DB,
    nick: uint16,
    merit: int
) {.forceCheck: [].} =
    db.put(MERIT(nick), merit.toBinary())

proc remove*(
    db: DB,
    nick: uint16,
    merit: int,
    blockNum: int
) {.forceCheck: [].} =
    db.merit.removals[nick] = merit

    var removals: string
    try:
        removals = db.get(HOLDER_REMOVALS(nick))
    except DBReadError:
        discard
    db.put(HOLDER_REMOVALS(nick), removals & blockNum.toBinary(INT_LEN))

#Load functions.
proc loadUpcomingKey*(
    db: DB
): string {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(UPCOMING_RANDOMX_KEY())
    except DBReadError as e:
        raise e

proc loadKey*(
    db: DB
): string {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(RANDOMX_KEY())
    except DBReadError as e:
        raise e

proc loadHeight*(
    db: DB
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(HEIGHT()).fromBinary()
    except Exception as e:
        raise newLoggedException(DBReadError, e.msg)

proc loadTip*(
    db: DB
): Hash[256] {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(TIP()).toHash(256)
    except Exception as e:
        raise newLoggedException(DBReadError, e.msg)

proc loadDifficulty*(
    db: DB,
    hash: Hash[256]
): Difficulty {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(DIFFICULTY(hash)).parseDifficulty()
    except Exception as e:
        raise newLoggedException(DBReadError, e.msg)

proc loadUnlocked*(
    db: DB,
    blockNum: int
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(TOTAL_UNLOCKED_MERIT(blockNum)).fromBinary()
    except DBReadError as e:
        raise e

proc loadBlockHeader*(
    db: DB,
    hash: Hash[256]
): BlockHeader {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(BLOCK_HASH(hash)).parseBlockHeader(db.get(INTERIM_HASH(hash)), hash)
    except Exception as e:
        raise newLoggedException(DBReadError, e.msg)

proc loadBlock*(
    db: DB,
    hash: Hash[256]
): Block {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(BLOCK_HASH(hash)).parseBlock(db.get(INTERIM_HASH(hash)), hash)
    except Exception as e:
        raise newLoggedException(DBReadError, e.msg)

proc loadBlock*(
    db: DB,
    nonce: int
): Block {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.loadBlock(db.get(BLOCK_NONCE(nonce)).toHash(256))
    except Exception as e:
        raise newLoggedException(DBReadError, e.msg)

proc loadHolders*(
    db: DB
): seq[BLSPublicKey] {.forceCheck: [].} =
    var holders: int
    try:
        holders = db.get(HOLDERS).fromBinary()
    except DBReadError:
        return

    result = newSeq[BLSPublicKey](holders)
    for h in 0 ..< holders:
        try:
            result[h] = newBLSPublicKey(db.get(HOLDER_NICK(uint16(h))))
        except DBReadError as e:
            panic("Couldn't get a holder's BLS Public Key: " & e.msg)
        except BLSError as e:
            panic("Couldn't load a holder's BLS Public Key: " & e.msg)

proc loadNickname*(
    db: DB,
    key: BLSPublicKey
): uint16 {.forceCheck: [
    DBReadError
].} =
    try:
        result = uint16(db.get(HOLDER_KEY(key)).fromBinary())
    except DBReadError as e:
        raise e

proc loadMerit*(
    db: DB,
    nick: uint16
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(MERIT(nick)).fromBinary()
    except DBReadError as e:
        raise e

proc loadBlockRemovals*(
    db: DB,
    blockNum: int
): seq[tuple[nick: uint16, merit: int]] {.forceCheck: [].} =
    var removals: string
    try:
        removals = db.get(BLOCK_REMOVALS(blockNum))
    except DBReadError:
        return

    for i in countup(0, removals.len - 1, NICKNAME_LEN + INT_LEN):
        result.add(
            (
                nick: uint16(removals[i ..< i + NICKNAME_LEN].fromBinary()),
                merit: removals[i + NICKNAME_LEN ..< i + NICKNAME_LEN + INT_LEN].fromBinary()
            )
        )

proc loadHolderRemovals*(
    db: DB,
    nick: uint16
): seq[int] {.forceCheck: [].} =
    var removals: string
    try:
        removals = db.get(HOLDER_REMOVALS(nick))
    except DBReadError:
        return

    for i in countup(0, removals.len - 1, 4):
        result.add(removals[i ..< i + 4].fromBinary())

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

#Delete a Block.
proc deleteBlock*(
    db: DB,
    nonce: int,
    elements: seq[BlockElement]
) {.forceCheck: [].} =
    var hash: Hash[256]
    try:
        hash = db.get(BLOCK_NONCE(nonce)).toHash(256)
    except ValueError as e:
        panic("Couldn't convert a 32-byte value to a 32-byte hash: " & e.msg)
    except DBReadError as e:
        panic("Tried to delete a Block which doesn't exist: " & e.msg)

    db.del(BLOCK_NONCE(nonce))
    db.del(INTERIM_HASH(hash))
    db.del(BLOCK_HASH(hash))
    db.del(DIFFICULTY(hash))
    db.del(TOTAL_UNLOCKED_MERIT(nonce))
    db.del(BLOCK_REMOVALS(nonce))

    for elem in elements:
        if elem of MeritRemoval:
            var removals: string
            try:
                removals = db.get(HOLDER_REMOVALS(cast[MeritRemoval](elem).holder))
            except DBReadError as e:
                panic("Couldn't get the removals of a holder with a MeritRemoval: " & e.msg)
            if removals.len == INT_LEN:
                db.del(HOLDER_REMOVALS(cast[MeritRemoval](elem).holder))
            else:
                db.put(HOLDER_REMOVALS(cast[MeritRemoval](elem).holder), removals[0 ..< removals.len - INT_LEN])

#Delete the latest holder.
proc deleteHolder*(
    db: DB
) {.forceCheck: [].} =
    var holders: uint16
    try:
        holders = uint16(db.get(HOLDERS()).fromBinary() - 1)
    except DBReadError as e:
        panic("There isn't any holders to delete: " & e.msg)
    db.put(HOLDERS(), holders.toBinary())

    try:
        db.del(HOLDER_KEY(db.get(HOLDER_NICK(holders))))
    except DBReadError as e:
        panic("Tried to delete a holder who didn't have their key saved: " & e.msg)
    db.del(HOLDER_NICK(holders))
    db.del(MERIT(holders))
    db.del(HOLDER_REMOVALS(holders))
