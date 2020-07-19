import sets, tables

import stint

import ../../../lib/[Errors, Util, Hash]
import ../../../Wallet/MinerWallet

import ../../Consensus/Elements/Elements

import ../../Merit/objects/[BlockHeaderObj, BlockObj]

import ../../../Network/Serialize/SerializeCommon

import Serialize/Merit/[DBSerializeBlock, DBParseBlockHeader, DBParseBlock]

import objects/DBObj
export DBObj

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

template TOTAL_MERIT(
  blockNum: int
): string =
  blockNum.toBinary(INT_LEN) & "t"

template PENDING_MERIT(
  blockNum: int
): string =
  blockNum.toBinary(INT_LEN) & "p"

template COUNTED_MERIT(
  blockNum: int
): string =
  blockNum.toBinary(INT_LEN) & "c"

template INTERIM_HASH(
  hash: Hash[256]
): string =
  hash.serialize() & "i"

template BLOCK_HASH(
  hash: Hash[256]
): string =
  hash.serialize()

template BLOCK_NONCE(
  nonce: int
): string =
  nonce.toBinary(INT_LEN)

template BLOCK_HEIGHT(
  hash: Hash[256]
): string =
  hash.serialize() & "h"

template DIFFICULTY(
  hash: Hash[256]
): string =
  hash.serialize() & "d"

template CHAIN_WORK(
  hash: Hash[256]
): string =
  hash.serialize() & "w"

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

template MERIT_STATUSES(
  nick: uint16
): string =
  nick.toBinary(NICKNAME_LEN) & "s"

template LAST_PARTICIPATIONS(
  nick: uint16
): string =
  nick.toBinary(NICKNAME_LEN) & "p"

template BLOCK_REMOVALS(
  blockNum: int
): string =
  blockNum.toBinary(INT_LEN) & "r"

template HOLDER_REMOVALS(
  nick: uint16
): string =
  nick.toBinary(NICKNAME_LEN) & "r"

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
  db.put(TIP(), hash.serialize())

proc save*(
  db: DB,
  hash: Hash[256],
  difficulty: uint64
) {.forceCheck: [].} =
  db.put(DIFFICULTY(hash), difficulty.toBinary())

proc saveMerits*(
  db: DB,
  blockNum: int,
  total: int,
  pending: int,
  counted: int
) {.forceCheck: [].} =
  db.put(TOTAL_MERIT(blockNum), total.toBinary())
  db.put(PENDING_MERIT(blockNum), pending.toBinary())
  db.put(COUNTED_MERIT(blockNum), counted.toBinary())

proc save*(
  db: DB,
  nonce: int,
  blockArg: Block
) {.forceCheck: [].} =
  db.put(INTERIM_HASH(blockArg.header.hash), blockArg.header.interimHash)
  db.put(BLOCK_HASH(blockArg.header.hash), blockArg.serialize())
  db.put(BLOCK_NONCE(nonce), blockArg.header.hash.serialize())
  db.put(BLOCK_HEIGHT(blockArg.header.hash), (nonce + 1).toBinary())

proc save*(
  db: DB,
  hash: Hash[256],
  work: StUInt[128]
) {.forceCheck: [].} =
  var workStr: string
  for b in work.toBytesLE():
    workStr &= char(b)
  db.put(CHAIN_WORK(hash), workStr)

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

proc appendMeritStatus*(
  db: DB,
  nick: uint16,
  processed: int,
  status: byte
) {.forceCheck: [].} =
  var existing: string
  try:
    existing = db.get(MERIT_STATUSES(nick))
  except DBReadError:
    discard
  db.put(MERIT_STATUSES(nick), existing & processed.toBinary(INT_LEN) & status.toBinary(BYTE_LEN))

proc overrideMeritStatuses*(
  db: DB,
  nick: uint16,
  statuses: string
) {.forceCheck: [].} =
  if statuses.len == 0:
    db.del(MERIT_STATUSES(nick))
  else:
    db.put(MERIT_STATUSES(nick), statuses)

proc appendLastParticipation*(
  db: DB,
  nick: uint16,
  processed: int,
  last: int
) {.forceCheck: [].} =
  var existing: string
  try:
    existing = db.get(LAST_PARTICIPATIONS(nick))
  except DBReadError:
    discard
  db.put(LAST_PARTICIPATIONS(nick), existing & processed.toBinary(INT_LEN) & last.toBinary(INT_LEN))

proc overrideLastParticipations*(
  db: DB,
  nick: uint16,
  participations: string
) {.forceCheck: [].} =
  if participations.len == 0:
    db.del(LAST_PARTICIPATIONS(nick))
  else:
    db.put(LAST_PARTICIPATIONS(nick), participations)

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
    result = db.get(TIP()).toHash[:256]()
  except Exception as e:
    raise newLoggedException(DBReadError, e.msg)

proc loadDifficulty*(
  db: DB,
  hash: Hash[256]
): uint64 {.forceCheck: [
  DBReadError
].} =
  try:
    result = uint64(db.get(DIFFICULTY(hash)).fromBinary())
  except Exception as e:
    raise newLoggedException(DBReadError, e.msg)

proc loadChainWork*(
  db: DB,
  hash: Hash[256]
): StUInt[128] {.forceCheck: [].} =
  try:
    result = StUInt[128].fromBytesLE(cast[seq[byte]](db.get(CHAIN_WORK(hash))))
  except Exception as e:
    panic("Failed to get the chain work of a Block: " & e.msg)

proc loadTotal*(
  db: DB,
  blockNum: int
): int {.forceCheck: [
  DBReadError
].} =
  try:
    result = db.get(TOTAL_MERIT(blockNum)).fromBinary()
  except DBReadError as e:
    raise e

proc loadPending*(
  db: DB,
  blockNum: int
): int {.forceCheck: [
  DBReadError
].} =
  try:
    result = db.get(PENDING_MERIT(blockNum)).fromBinary()
  except DBReadError as e:
    raise e

proc loadCounted*(
  db: DB,
  blockNum: int
): int {.forceCheck: [
  DBReadError
].} =
  try:
    result = db.get(COUNTED_MERIT(blockNum)).fromBinary()
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
    result = db.loadBlock(db.get(BLOCK_NONCE(nonce)).toHash[:256]())
  except Exception as e:
    raise newLoggedException(DBReadError, e.msg)

proc loadHeight*(
  db: DB,
  hash: Hash[256]
): int {.forceCheck: [].} =
  try:
    result = db.get(BLOCK_HEIGHT(hash)).fromBinary()
  except Exception as e:
    panic("Couldn't load the height of a Block: " & e.msg)

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

proc loadMeritStatuses*(
  db: DB,
  nick: uint16
): string {.forceCheck: [].} =
  try:
    result = db.get(MERIT_STATUSES(nick))
  except DBReadError:
    discard

proc loadLastParticipations*(
  db: DB,
  nick: uint16
): string {.forceCheck: [].} =
  try:
    result = db.get(LAST_PARTICIPATIONS(nick))
  except DBReadError:
    discard

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

proc hasBlock*(
  db: DB,
  hash: Hash[256]
): bool {.forceCheck: [].} =
  try:
    discard db.get(hash.serialize())
    return true
  except DBReadError:
    return false

proc deleteUpcomingKey*(
  db: DB
) {.forceCheck: [].} =
  db.del(UPCOMING_RANDOMX_KEY())

proc deleteBlock*(
  db: DB,
  nonce: int,
  elements: seq[BlockElement]
) {.forceCheck: [].} =
  var hash: Hash[256]
  try:
    hash = db.get(BLOCK_NONCE(nonce)).toHash[:256]()
  except ValueError as e:
    panic("Couldn't convert a 32-byte value to a 32-byte hash: " & e.msg)
  except DBReadError as e:
    panic("Tried to delete a Block which doesn't exist: " & e.msg)

  db.del(BLOCK_NONCE(nonce))
  db.del(BLOCK_HEIGHT(hash))
  db.del(INTERIM_HASH(hash))
  db.del(BLOCK_HASH(hash))
  db.del(DIFFICULTY(hash))
  db.del(CHAIN_WORK(hash))
  db.del(TOTAL_MERIT(nonce))
  db.del(PENDING_MERIT(nonce))
  db.del(COUNTED_MERIT(nonce))
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
