import sets, tables

import ../../../lib/[Errors, Util, Hash]
import ../../../Wallet/Wallet

import ../../Transactions/Transaction

import ../../../Network/Serialize/SerializeCommon

import Serialize/Transactions/[
  SerializeMintOutput,
  SerializeSendOutput,
  DBSerializeTransaction
]

import Serialize/Transactions/[
  ParseMintOutput,
  ParseSendOutput,
  ParseTransaction
]

import objects/DBObj
export DBObj

template DATA_WALLET(): string =
  "w"

template UNMENTIONED_TRANSACTIONS(): string =
  "u"

template TRANSACTION(
  hash: Hash[256]
): string =
  hash.serialize()

template OUTPUT_SPENDERS(
  input: Input
): string =
  input.serialize() & "$"

template OUTPUT(
  hash: Hash[256],
  o: int
): string =
  hash.serialize() & o.toBinary(BYTE_LEN)

template OUTPUT(
  output: Input
): string =
  input.serialize()

template USED_KEY(
  key: RistrettoPublicKey
): string =
  key.serialize() & "uk"

template DATA_SENDER(
  hash: Hash[256]
): string =
  hash.serialize() & "se"

template SPENDABLE(
  key: RistrettoPublicKey
): string =
  key.serialize() & "$p"

template BEATEN_TRANSACTION(
  hash: Hash[256]
): string =
  hash.serialize() & "bt"

proc put(
  db: DB,
  key: string,
  val: string
) {.forceCheck: [].} =
  db.transactions.cache[key] = val
  db.transactions.deleted.excl(key)

proc get(
  db: DB,
  key: string
): string {.forceCheck: [
  DBReadError
].} =
  if db.transactions.deleted.contains(key):
    raise newLoggedException(DBReadError, "Key deleted.")

  if db.transactions.cache.hasKey(key):
    try:
      return db.transactions.cache[key]
    except KeyError as e:
      panic("Couldn't get a key from a table confirmed to exist: " & e.msg)

  try:
    result = db.lmdb.get("transactions", key)
  except Exception as e:
    raise newLoggedException(DBReadError, e.msg)

proc del(
  db: DB,
  key: string
) {.forceCheck: [].} =
  db.transactions.deleted.incl(key)
  db.transactions.cache.del(key)

proc commit*(
  db: DB,
  tx: LMDBTransaction
) {.forceCheck: [].} =
  for key in db.transactions.deleted:
    try:
      #If the key doesn't exist, this TX will error.
      discard db.lmdb.get("transactions", key)
      #If we waited for this TX to error, it'd kill the batch.
      db.lmdb.delete(tx, "transactions", key)
    except KeyError:
      panic("Tried to grab a key from a Database which doesn't exist.")
    except DBError:
      continue
  db.transactions.deleted = initHashSet[string]()

  try:
    for key in db.transactions.cache.keys():
      db.lmdb.put(tx, "transactions", key, db.transactions.cache[key])
  except KeyError as e:
    panic("Couldn't get a value from the table despiting getting the key from .keys() OR trying to write to a Database which doesn't exist: " & e.msg)
  except DBError as e:
    panic("Couldn't write to a Database: " & e.msg)

  var unmentioned: string
  for hash in db.transactions.unmentioned:
    unmentioned &= hash.serialize()
  try:
    db.lmdb.put(tx, "transactions", UNMENTIONED_TRANSACTIONS(), unmentioned)
  except KeyError as e:
    panic("Tried to write to a Database which doesn't exist: " & e.msg)
  except DBError as e:
    panic("Couldn't write to a Database: " & e.msg)

  db.transactions.cache = initTable[string, string]()

proc saveDataWallet*(
  db: DB,
  mnemonic: string
) {.inline, forceCheck: [].} =
  db.put(DATA_WALLET(), mnemonic)

proc save*(
  db: DB,
  tx: Transaction
) {.forceCheck: [].} =
  db.put(TRANSACTION(tx.hash), tx.serialize())
  db.transactions.unmentioned.incl(tx.hash)

  if not ((tx of Data) and cast[Data](tx).isFirstData):
    for input in tx.inputs:
      try:
        db.put(OUTPUT_SPENDERS(input), db.get(OUTPUT_SPENDERS(input)) & tx.hash.serialize())
      except DBReadError:
        db.put(OUTPUT_SPENDERS(input), tx.hash.serialize())

  for o in 0 ..< tx.outputs.len:
    db.put(OUTPUT(tx.hash, o), tx.outputs[o].serialize())

    #Save Ed keys as used if they're sent to.
    if (tx of Claim) or (tx of Send):
      db.put(USED_KEY(cast[SendOutput](tx.outputs[o]).key), "")

proc mention*(
  db: DB,
  hash: Hash[256]
) {.forceCheck: [].} =
  db.transactions.unmentioned.excl(hash)

proc unmention*(
  db: DB,
  hashes: HashSet[Hash[256]]
) {.inline, forceCheck: [].} =
  db.transactions.unmentioned = db.transactions.unmentioned + hashes

proc saveDataSender*(
  db: DB,
  data: Data,
  sender: RistrettoPublicKey
) {.forceCheck: [].} =
  db.put(DATA_SENDER(data.hash), sender.serialize())

proc loadUnmentioned*(
  db: DB
): HashSet[Hash[256]] {.forceCheck: [].} =
  var unmentioned: string
  try:
    unmentioned = db.get(UNMENTIONED_TRANSACTIONS())
  except DBReadError:
    return

  result = initHashSet[Hash[256]]()
  for h in 0 ..< unmentioned.len div 32:
    result.incl(unmentioned[h * 32 ..< (h + 1) * 32].toHash[:256]())
  db.transactions.unmentioned = result

proc loadDataWallet*(
  db: DB,
): string {.forceCheck: [
  DBReadError
].} =
  try:
    result = db.get(DATA_WALLET())
  except Exception as e:
    raise newLoggedException(DBReadError, e.msg)

proc load*(
  db: DB,
  hash: Hash[256]
): Transaction {.forceCheck: [
  DBReadError
].} =
  try:
    result = hash.parseTransaction(db.get(TRANSACTION(hash)))
  except Exception as e:
    raise newLoggedException(DBReadError, e.msg)

  #Recalculate the output amount if this is a Claim.
  if result of Claim:
    var
      claim: Claim = cast[Claim](result)
      amount: uint64 = 0
    for input in claim.inputs:
      try:
        amount += db.get(OUTPUT(input)).parseMintOutput().amount
      except Exception as e:
        panic("Claim's spent Mints' outputs couldn't be loaded from the DB: " & e.msg)

    claim.outputs[0].amount = amount

proc loadIfKeyWasUsed*(
  db: DB,
  key: RistrettoPublicKey
): bool {.forceCheck: [].} =
  try:
    discard db.get(USED_KEY(key))
    result = true
  except DBReadError:
    result = false

proc isBeaten*(
  db: DB,
  hash: Hash[256]
): bool {.forceCheck: [].} =
  try:
    discard db.get(BEATEN_TRANSACTION(hash))
    result = true
  except DBReadError:
    result = false

proc loadSpenders*(
  db: DB,
  input: Input
): seq[Hash[256]] {.forceCheck: [].} =
  var spenders: string = ""
  try:
    spenders = db.get(OUTPUT_SPENDERS(input))
  except DBReadError:
    return

  for h in countup(0, spenders.len - 1, 32):
    result.add(spenders[h ..< h + 32].toHash[:256]())

proc loadDataSender*(
  db: DB,
  hash: Hash[256]
): RistrettoPublicKey {.forceCheck: [
  DBReadError
].} =
  try:
    result = newRistrettoPublicKey(db.get(DATA_SENDER(hash)))
  except Exception as e:
    raise newLoggedException(DBReadError, e.msg)

proc loadMintOutput*(
  db: DB,
  input: FundedInput
): MintOutput {.forceCheck: [
  DBReadError
].} =
  try:
    result = db.get(OUTPUT(input)).parseMintOutput()
  except Exception as e:
    raise newLoggedException(DBReadError, e.msg)

proc loadSendOutput*(
  db: DB,
  input: FundedInput
): SendOutput {.forceCheck: [
  DBReadError
].} =
  try:
    result = db.get(OUTPUT(input)).parseSendOutput()
  except Exception as e:
    raise newLoggedException(DBReadError, e.msg)

proc loadSpendable*(
  db: DB,
  key: RistrettoPublicKey
): seq[FundedInput] {.forceCheck: [
  DBReadError
].} =
  var spendable: string
  try:
    spendable = db.get(SPENDABLE(key))
  except Exception as e:
    raise newLoggedException(DBReadError, e.msg)

  for i in countup(0, spendable.len - 1, 33):
    let input: FundedInput = newFundedInput(
      spendable[i ..< i + 32].toHash[:256](),
      int(spendable[i + 32])
    )

    #Spendable isn't guaranteed consistency for a few reasons. This manifests as spent Transactions reappearing.
    #Without a lot more tracking code, which would be decently intensive, it can't be made consistent.
    #That said, by following up with this check, it can be.
    #Theoretically, we could also move this check to addToSpendable, yet addToSpendable is caused for all UTXOs.
    #loadSpendable is solely triggered via the RPC and therefore should run much more infrequently.
    if db.loadSpenders(input).len == 0:
      result.add(input)

proc addToSpendable(
  db: DB,
  key: RistrettoPublicKey,
  hash: Hash[256],
  nonce: int
) {.forceCheck: [].} =
  try:
    db.put(SPENDABLE(key), db.get(SPENDABLE(key)) & hash.serialize() & char(nonce))
  except DBReadError:
    db.put(SPENDABLE(key), hash.serialize() & char(nonce))

proc removeFromSpendable(
  db: DB,
  key: RistrettoPublicKey,
  hash: Hash[256],
  nonce: int
) {.forceCheck: [].} =
  var
    output: string = hash.serialize() & char(nonce)
    spendable: string

  #Load the output.
  try:
    spendable = db.get(SPENDABLE(key))
  except DBReadError:
    return

  #Remove all occurrences of the specified output.
  var o: int = 0
  while o < spendable.len:
    if spendable[o ..< o + 33] == output:
      spendable = spendable[0 ..< o] & spendable[o + 33 ..< spendable.len]
      continue
    o += 33
  db.put(SPENDABLE(key), spendable)

#Add the Transaction's outputs to spendable.
proc verify*(
  db: DB,
  tx: Transaction
) {.forceCheck: [].} =
  if (tx of Claim) or (tx of Send):
    for o in 0 ..< tx.outputs.len:
      db.addToSpendable(
        cast[SendOutput](tx.outputs[o]).key,
        tx.hash,
        o
      )

#Removes outputs from spendable.
proc unverify*(
  db: DB,
  tx: Transaction
) {.forceCheck: [].} =
  if (tx of Claim) or (tx of Send):
    for o in 0 ..< tx.outputs.len:
      db.removeFromSpendable(
        cast[SendOutput](tx.outputs[o]).key,
        tx.hash,
        o
      )

#Mark a Transaction as beaten.
proc beat*(
  db: DB,
  hash: Hash[256]
) {.forceCheck: [].} =
  db.put(BEATEN_TRANSACTION(hash), "")

#Prune a Transaction.
proc prune*(
  db: DB,
  hash: Hash[256]
) {.forceCheck: [].} =
  #Get the TX.
  var tx: Transaction
  try:
    tx = db.load(hash)
  except DBReadError:
    return

  #Delete the Transaction.
  db.del(TRANSACTION(hash))

  #Delete if it was beaten.
  db.del(BEATEN_TRANSACTION(hash))

  #Delete if its unmentioned.
  db.transactions.unmentioned.excl(hash)

  #Remove it as a spender.
  var hashStr: string = hash.serialize()
  for i in 0 ..< tx.inputs.len:
    var spenders: string
    try:
      spenders = db.get(OUTPUT_SPENDERS(tx.inputs[i]))
    except DBReadError as e:
      panic("Couldn't get the spenders of a spent input: " & e.msg)

    for h in countup(0, spenders.len - 1, 32):
      if spenders[h ..< h + 32] == hashStr:
        spenders = spenders[0 ..< h] & spenders[h + 32 ..< spenders.len]
        break

    db.put(OUTPUT_SPENDERS(tx.inputs[i]), spenders)

  for o in 0 ..< tx.outputs.len:
    #Delete its outputs and their spenders.
    db.del(OUTPUT(hash, o))
    var spenders: string
    try:
      spenders = db.get(OUTPUT_SPENDERS(newFundedInput(hash, o)))
    except DBReadError:
      discard
    db.del(OUTPUT_SPENDERS(newFundedInput(hash, o)))

    #If it is tracked by spendable, remove it.
    #Should be handled by unverify, so I'm not really sure why this is here.
    #That said, it doesn't hurt to have, and it's safe to run even if the outputs aren't present in spendable.
    #-- Kayaba
    if tx.outputs[o] of SendOutput:
      db.removeFromSpendable(cast[SendOutput](tx.outputs[o]).key, hash, o)
