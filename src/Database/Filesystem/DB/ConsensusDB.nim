import sets, tables

import ../../../lib/[Errors, Util, Hash]
import ../../../Wallet/MinerWallet

import ../../Consensus/Elements/Elements
import ../../Consensus/objects/TransactionStatusObj

import ../../../Network/Serialize/SerializeCommon
import ../../../Network/Serialize/Consensus/[SerializeMeritRemoval, ParseMeritRemoval]

import Serialize/Consensus/[SerializeTransactionStatus, ParseTransactionStatus]

import objects/DBObj
export DBObj

template STATUS(
  hash: Hash[256]
): string =
  hash.serialize()

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

template SEND_DIFFICULTY_NONCE(
  holder: uint16
): string =
  holder.toBinary(NICKNAME_LEN) & "sn"

template HOLDER_DATA_DIFFICULTY(
  holder: uint16
): string =
  holder.toBinary(NICKNAME_LEN) & "d"

template DATA_DIFFICULTY_NONCE(
  holder: uint16
): string =
  holder.toBinary(NICKNAME_LEN) & "dn"

template BLOCK_ELEMENT(
  holder: uint16,
  nonce: int
): string =
  holder.toBinary(NICKNAME_LEN) & nonce.toBinary(INT_LEN)

template SIGNATURE(
  holder: uint16,
  nonce: int
): string =
  BLOCK_ELEMENT(holder, nonce) & "s"

template MALICIOUS_PROOFS(): string =
  "p"

template HOLDER_MALICIOUS_PROOF_QUANTITY(
  holder: uint16
): string =
  holder.toBinary(NICKNAME_LEN) & "p"

template HOLDER_MALICIOUS_PROOF(
  holder: uint16,
  nonce: int
): string =
  holder.toBinary(NICKNAME_LEN) & nonce.toBinary(INT_LEN) & "p"

proc put(
  db: DB,
  key: string,
  val: string
) {.forceCheck: [].} =
  db.consensus.cache[key] = val
  db.consensus.deleted.excl(key)

proc get(
  db: DB,
  key: string
): string {.forceCheck: [
  DBReadError
].} =
  if db.consensus.deleted.contains(key):
    raise newLoggedException(DBReadError, "Key deleted.")

  if db.consensus.cache.hasKey(key):
    try:
      return db.consensus.cache[key]
    except KeyError as e:
      panic("Couldn't get a key from a table confirmed to exist: " & e.msg)

  try:
    result = db.lmdb.get("consensus", key)
  except Exception as e:
    raise newLoggedException(DBReadError, e.msg)

proc del(
  db: DB,
  key: string
) {.forceCheck: [].} =
  db.consensus.deleted.incl(key)
  db.consensus.cache.del(key)

proc commit*(
  db: DB,
  tx: LMDBTransaction
) {.forceCheck: [].} =
  for key in db.consensus.deleted:
    try:
      discard db.lmdb.get("consensus", key)
      db.lmdb.delete(tx, "consensus", key)
    except KeyError:
      panic("Tried to grab a key from a Database which doesn't exist.")
    except DBError:
      continue
  db.consensus.deleted = initHashSet[string]()

  try:
    for key in db.consensus.cache.keys():
      db.lmdb.put(tx, "consensus", key, db.consensus.cache[key])
  except KeyError as e:
    panic("Couldn't get a value from the table despiting getting the key from .keys() OR trying to write to a Database which doesn't exist: " & e.msg)
  except DBError as e:
    panic("Couldn't write to a Database: " & e.msg)

  #Save the unmentioned hashes.
  var unmentioned: string
  for hash in db.consensus.unmentioned:
    unmentioned &= hash.serialize()
  try:
    db.lmdb.put(tx, "consensus", UNMENTIONED(), unmentioned)
  except KeyError as e:
    panic("Tried to write to a Database which doesn't exist: " & e.msg)
  except DBError as e:
    panic("Couldn't write to a Database: " & e.msg)
  db.consensus.unmentioned = initHashSet[Hash[256]]()

  db.consensus.cache = initTable[string, string]()

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
  db.consensus.unmentioned.incl(unmentioned)

proc mention*(
  db: DB,
  mentioned: Hash[256]
) {.inline, forceCheck: [].} =
  db.consensus.unmentioned.excl(mentioned)

proc save*(
  db: DB,
  sendDiff: SendDifficulty
) {.forceCheck: [].} =
  db.put(HOLDER_NONCE(sendDiff.holder), sendDiff.nonce.toBinary())
  db.put(HOLDER_SEND_DIFFICULTY(sendDiff.holder), sendDiff.difficulty.toBinary(INT_LEN))
  db.put(SEND_DIFFICULTY_NONCE(sendDiff.holder), sendDiff.nonce.toBinary())

  db.put(
    BLOCK_ELEMENT(sendDiff.holder, sendDiff.nonce),
    char(SEND_DIFFICULTY_PREFIX) & sendDiff.difficulty.toBinary(INT_LEN)
  )

proc override*(
  db: DB,
  holder: uint16,
  nonce: int
) {.forceCheck: [].} =
  db.put(HOLDER_NONCE(holder), nonce.toBinary())
  db.put(HOLDER_ARCHIVED_NONCE(holder), nonce.toBinary())

proc override*(
  db: DB,
  sendDiff: SendDifficulty
) {.forceCheck: [].} =
  db.put(HOLDER_SEND_DIFFICULTY(sendDiff.holder), sendDiff.difficulty.toBinary(INT_LEN))
  db.put(SEND_DIFFICULTY_NONCE(sendDiff.holder), sendDiff.nonce.toBinary())

proc override*(
  db: DB,
  dataDiff: DataDifficulty
) {.forceCheck: [].} =
  db.put(HOLDER_DATA_DIFFICULTY(dataDiff.holder), dataDiff.difficulty.toBinary(INT_LEN))
  db.put(DATA_DIFFICULTY_NONCE(dataDiff.holder), dataDiff.nonce.toBinary())

proc save*(
  db: DB,
  dataDiff: DataDifficulty
) {.forceCheck: [].} =
  db.put(HOLDER_NONCE(dataDiff.holder), dataDiff.nonce.toBinary())
  db.put(HOLDER_DATA_DIFFICULTY(dataDiff.holder), dataDiff.difficulty.toBinary(INT_LEN))
  db.put(DATA_DIFFICULTY_NONCE(dataDiff.holder), dataDiff.nonce.toBinary())

  db.put(
    BLOCK_ELEMENT(dataDiff.holder, dataDiff.nonce),
    char(DATA_DIFFICULTY_PREFIX) & dataDiff.difficulty.toBinary(INT_LEN)
  )

proc saveSignature*(
  db: DB,
  holder: uint16,
  nonce: int,
  signature: BLSSignature
) {.inline, forceCheck: [].} =
  db.put(SIGNATURE(holder, nonce), signature.serialize())

proc saveArchived*(
  db: DB,
  holder: uint16,
  nonce: int
) {.inline, forceCheck: [].} =
  db.put(HOLDER_ARCHIVED_NONCE(holder), nonce.toBinary())

proc saveMaliciousProof*(
  db: DB,
  mr: SignedMeritRemoval
) {.forceCheck: [].} =
  var nonce: int = 1
  try:
    nonce = db.get(HOLDER_MALICIOUS_PROOF_QUANTITY(mr.holder)).fromBinary() + 1
  except DBReadError:
    discard
  db.put(HOLDER_MALICIOUS_PROOF(mr.holder, nonce - 1), mr.serialize())
  db.put(HOLDER_MALICIOUS_PROOF_QUANTITY(mr.holder), nonce.toBinary())

  if not db.consensus.malicious.contains(mr.holder):
    db.consensus.malicious.incl(mr.holder)
    var malicious: string = ""
    try:
      malicious = db.get(MALICIOUS_PROOFS())
    except DBReadError:
      discard
    db.put(MALICIOUS_PROOFS(), malicious & mr.holder.toBinary(NICKNAME_LEN))

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
): HashSet[Hash[256]] {.forceCheck: [].} =
  result = initHashSet[Hash[256]]()

  var unmentioned: string
  try:
    unmentioned = db.get(UNMENTIONED())
  except DBReadError:
    return

  for h in countup(0, unmentioned.len - 1, 32):
    result.incl(unmentioned[h ..< h + 32].toHash[:256]())
  db.consensus.unmentioned = result

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
): uint32 {.forceCheck: [
  DBReadError
].} =
  try:
    result = uint32(db.get(HOLDER_SEND_DIFFICULTY(holder)).fromBinary())
  except ValueError:
    panic("Couldn't turn a 32-byte value into a 32-byte hash.")
  except DBReadError as e:
    raise e

proc loadSendDifficultyNonce*(
  db: DB,
  holder: uint16
): int {.forceCheck: [].} =
  try:
    result = db.get(SEND_DIFFICULTY_NONCE(holder)).fromBinary()
  except DBReadError:
    return -1

proc loadDataDifficulty*(
  db: DB,
  holder: uint16
): uint32 {.forceCheck: [
  DBReadError
].} =
  try:
    result = uint32(db.get(HOLDER_DATA_DIFFICULTY(holder)).fromBinary())
  except ValueError:
    panic("Couldn't turn a 32-byte value into a 32-byte hash.")
  except DBReadError as e:
    raise e

proc loadDataDifficultyNonce*(
  db: DB,
  holder: uint16
): int {.forceCheck: [].} =
  try:
    result = db.get(DATA_DIFFICULTY_NONCE(holder)).fromBinary()
  except DBReadError:
    return -1

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
        result = newSendDifficultyObj(nonce, uint32(elem[1 ..< 5].fromBinary()))
        result.holder = holder
      of DATA_DIFFICULTY_PREFIX:
        result = newDataDifficultyObj(nonce, uint32(elem[1 ..< 5].fromBinary()))
        result.holder = holder
      else:
        panic("Tried to load an unknown Block Element: " & $int(elem[0]))
  except ValueError:
    panic("Couldn't convert a 32-byte value to a 32-byte hash.")

proc loadSignature*(
  db: DB,
  holder: uint16,
  nonce: int
): BLSSignature {.forceCheck: [
  DBReadError
].} =
  try:
    result = newBLSSignature(db.get(SIGNATURE(holder, nonce)))
  except BLSError as e:
    panic("Saved an invalid BLS signature to the Database: " & e.msg)
  except DBReadError as e:
    raise e

proc loadArchived*(
  db: DB,
  holder: uint16
): int {.forceCheck: [].} =
  try:
    result = db.get(HOLDER_ARCHIVED_NONCE(holder)).fromBinary()
  except DBReadError:
    result = -1

#Load the malicious proofs table.
proc loadMaliciousProofs*(
  db: DB
): Table[uint16, seq[SignedMeritRemoval]] {.forceCheck: [].} =
  result = initTable[uint16, seq[SignedMeritRemoval]]()

  var malicious: string = ""
  try:
    malicious = db.get(MALICIOUS_PROOFS())
  except DBReadError:
    discard

  for h in countup(0, malicious.len - 1, NICKNAME_LEN):
    var holder: uint16 = uint16(malicious[h ..< h + NICKNAME_LEN].fromBinary())
    db.consensus.malicious.incl(holder)
    result[holder] = @[]

    try:
      for p in 0 ..< db.get(HOLDER_MALICIOUS_PROOF_QUANTITY(holder)).fromBinary():
        try:
          result[holder].add(db.get(HOLDER_MALICIOUS_PROOF(holder, p)).parseSignedMeritRemoval())
        except ValueError as e:
          panic("Couldn't parse a MeritRemoval we saved to the database as a malicious proof: " & e.msg)
    except DBReadError:
      panic("Malicious holder didn't have any proofs saved.")

#[
Delete a Transaction Status.
We used to have a function called prune which also deleted the Transaction itself from this DB.
This was when the Consensus DB did save some TXs used in MRs which were no longer valid against the current DAG.
With implicit Merit Removals, this functionality is gone.
Prune was also deleted, and all code was migrated to this function.
]#
proc delete*(
  db: DB,
  hash: Hash[256]
) {.forceCheck: [].} =
  db.del(STATUS(hash))
  db.consensus.unmentioned.excl(hash)

#Delete a Block Element.
proc delete*(
  db: DB,
  holder: uint16,
  nonce: int
) {.forceCheck: [].} =
  db.del(BLOCK_ELEMENT(holder, nonce))
  db.del(SIGNATURE(holder, nonce))

#Delete a now-aggregated signature.
proc deleteSignature*(
  db: DB,
  holder: uint16,
  nonce: int
) {.inline, forceCheck: [].} =
  db.del(SIGNATURE(holder, nonce))

proc deleteSendDifficulty*(
  db: DB,
  holder: uint16
) {.forceCheck: [].} =
  db.del(HOLDER_SEND_DIFFICULTY(holder))
  db.del(SEND_DIFFICULTY_NONCE(holder))

proc deleteDataDifficulty*(
  db: DB,
  holder: uint16
) {.forceCheck: [].} =
  db.del(HOLDER_DATA_DIFFICULTY(holder))
  db.del(DATA_DIFFICULTY_NONCE(holder))

proc deleteMaliciousProofs*(
  db: DB,
  holder: uint16
) {.forceCheck: [].} =
  db.consensus.malicious.excl(holder)

  #We actually don't want to delete any of these (https://github.com/MerosCrypto/Meros/issues/152).
  #We solely want to ignore them, which means removing the note to reload them as part of the cache.
  #Since implicit Merit Removals pemanently banned holders, we don't have to worry about overwrite.
  var malicious: string
  try:
    malicious = db.get(MALICIOUS_PROOFS())
  except DBReadError:
    return

  for h in countup(0, malicious.len - 1, NICKNAME_LEN):
    if holder == uint16(malicious[h ..< h + NICKNAME_LEN].fromBinary()):
      db.put(MALICIOUS_PROOFS(), malicious[0 ..< h] & malicious[h + NICKNAME_LEN ..< malicious.len])
      break
