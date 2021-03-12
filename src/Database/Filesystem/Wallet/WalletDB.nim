import tables

import mc_lmdb

import ../../../lib/[Errors, Util, Hash]
import ../../../Wallet/[MinerWallet, Wallet, HDWallet]

import ../../Transactions/objects/TransactionObj
import ../../Transactions/Data as DataFile

import ../../Merit/objects/EpochsObj

import ../../../Network/Serialize/SerializeCommon

import ../DB/Serialize/Transactions/[DBSerializeTransaction, ParseTransaction]

template MNEMONIC(): string =
  "w"

template DATA_TIP(): string =
  "d"

#_TX added so the symbol doesn't conflict with the Data type.
template DATA_TX(
  hash: Hash[256]
): string =
  "d" & hash.serialize()

template MINER_KEY(): string =
  "m"

template MINER_NICK(): string =
  "n"

template INPUT_NONCE(
  nonce: int
): string =
  nonce.toBinary(INT_LEN)

template FINALIZED_NONCES(): string =
  "fn"

template UNFINALIZED_NONCES(): string =
  "un"

template ELEMENT_NONCE(): string =
  "e"

template USING_ELEMENT_NONCE(): string =
  "u"

type
  LMDBTransaction = mc_lmdb.Transaction.Transaction
  MerosTransaction = TransactionObj.Transaction

  WalletDB* = ref object
    genesis: Hash[256]

    lmdb: LMDB

    wallet*: Wallet
    miner*: MinerWallet

    when defined(merosTests):
      finalizedNonces*: int
      unfinalizedNonces*: int
      verified*: Table[string, int]

      elementNonce*: int
    else:
      finalizedNonces: int
      unfinalizedNonces: int
      verified: Table[string, int]

      elementNonce: int

proc put(
  db: WalletDB,
  key: string,
  val: string
) {.forceCheck: [].} =
  try:
    var tx: LMDBTransaction = db.lmdb.newTransaction()
    db.lmdb.put(tx, "", key, val)
    tx.commit()
  except Exception as e:
    panic("Couldn't save data to the Database: " & e.msg)

proc put(
  db: WalletDB,
  items: seq[tuple[key: string, value: string]]
) {.forceCheck: [].} =
  try:
    var tx: LMDBTransaction = db.lmdb.newTransaction()
    for item in items:
      db.lmdb.put(tx, "", item.key, item.value)
    tx.commit()
  except Exception as e:
    panic("Couldn't save data to the Database: " & e.msg)

proc get(
  db: WalletDB,
  key: string
): string {.forceCheck: [
  DBReadError
].} =
  try:
    result = db.lmdb.get("", key)
  except Exception as e:
    raise newLoggedException(DBReadError, e.msg)

proc del(
  db: WalletDB,
  key: string
) {.forceCheck: [].} =
  try:
    var tx: LMDBTransaction = db.lmdb.newTransaction()
    db.lmdb.delete(tx, "", key)
    tx.commit()
  except Exception as e:
    panic("Couldn't delete data from the Database: " & e.msg)

proc commit*(
  db: WalletDB,
  popped: Epoch,
  getTransaction: proc (
    hash: Hash[256]
  ): MerosTransaction {.gcsafe, raises: [
    IndexError
  ].}
) {.forceCheck: [].} =
  #Mark all inputs of all finalized Transactions as finalized.
  var items: seq[tuple[key: string, value: string]] = newSeq[tuple[key: string, value: string]]()
  for hash in popped.keys():
    var tx: MerosTransaction
    try:
      tx = getTransaction(hash)
    except IndexError as e:
      panic("Couldn't get a Transaction that's now out of Epochs: " & e.msg)

    for input in tx.inputs:
      try:
        items.add((INPUT_NONCE(db.verified[input.serialize()]), char(1) & input.serialize()))
        #If the nonce of this input is the same as the last finalized nonce, increment.
        if db.verified[input.serialize()] == db.finalizedNonces:
          inc(db.finalizedNonces)
        db.verified.del(input.serialize())
      #We never verified a Transaction spending this input.
      except KeyError:
        continue
  db.put(items)

  #To handle out of order finalizations, do one last pass through.
  for n in db.finalizedNonces ..< db.unfinalizedNonces:
    try:
      if int(db.get(INPUT_NONCE(n))[0]) == 0:
        break
      inc(db.finalizedNonces)
    except DBReadError as e:
      panic("Couldn't get an input by its nonce: " & e.msg)

  #This is finalized outside of the singular Transaction as:
  #1) finalizedNonces is an optimation, not a requirement.
  #2) We need to read data we just modified in the Transaction.
  db.put(FINALIZED_NONCES(), db.finalizedNonces.toBinary())

proc newWalletDB*(
  genesis: Hash[256],
  path: string,
  size: int64
): WalletDB {.forceCheck: [
  DBError
].} =
  try:
    result = WalletDB(
      genesis: genesis,

      lmdb: newLMDB(path, size, 1),

      wallet: newWallet(""),
      miner: newMinerWallet(),

      finalizedNonces: 0,
      unfinalizedNonces: 0,
      verified: initTable[string, int](),

      elementNonce: 0
    )
    result.lmdb.open()
  except Exception as e:
    raise newLoggedException(DBError, "Couldn't open the WalletDB: " & e.msg)

  #Load the Wallet.
  try:
    result.wallet = newWallet(result.get(MNEMONIC()), "")
  except ValueError as e:
    panic("Failed to load the Wallet from the Database: " & e.msg)
  except DBReadError:
    result.put(MNEMONIC(), $result.wallet.mnemonic)

  #Load the MinerWallet.
  try:
    result.miner = newMinerWallet(result.get(MINER_KEY()))
  except BLSError as e:
    panic("Failed to load the MinerWallet from the Database: " & e.msg)
  except DBReadError:
    result.put(MINER_KEY(), result.miner.privateKey.serialize())

  try:
    result.miner.nick = uint16(result.get(MINER_NICK()).fromBinary())
    result.miner.initiated = true
  except DBReadError:
    discard

  #Load the input nonces.
  try:
    result.unfinalizedNonces = result.get(UNFINALIZED_NONCES()).fromBinary()
    result.finalizedNonces = result.get(FINALIZED_NONCES()).fromBinary()
  except DBReadError:
    discard

  #Load the verified Table.
  for n in result.finalizedNonces ..< result.unfinalizedNonces:
    var input: string
    try:
      input = result.get(INPUT_NONCE(n))
    except DBReadError as e:
      panic("Couldn't get an input by its nonce: " & e.msg)

    if int(input[0]) == 1:
      continue

    result.verified[input[1 ..< input.len]] = n

  #Load the Element nonce.
  try:
    #See getNonces for why this check exists.
    discard result.get(USING_ELEMENT_NONCE)
    panic("Node was terminated in the middle of creating a new Element.")
  except DBReadError:
    discard
  try:
    result.elementNonce = result.get(ELEMENT_NONCE()).fromBinary()
  except DBReadError:
    discard

proc close*(
  db: WalletDB
) {.forceCheck: [
  DBError
].} =
  try:
    db.lmdb.close()
  except Exception as e:
    raise newLoggedException(DBError, "Couldn't close the WalletDB: " & e.msg)

#Set the Wallet's mnemonic.
proc setWallet*(
  db: WalletDB,
  wallet: Wallet,
  datas: seq[Data]
) {.forceCheck: [].} =
  db.put(MNEMONIC(), $db.wallet.mnemonic)
  for data in datas:
    db.put(DATA_TX(data.hash), data.serialize())
  if datas.len != 0:
    db.put(DATA_TIP(), datas[0].hash.serialize())
  else:
    db.del(DATA_TIP())
  db.wallet = wallet

#Set our miner's nick.
proc setMinerNick*(
  db: WalletDB,
  nick: uint16
) {.forceCheck: [].} =
  db.miner.nick = nick
  db.miner.initiated = true
  db.put(MINER_KEY(), db.miner.privateKey.serialize())
  db.put(MINER_NICK(), nick.toBinary())

proc stepData*(
  db: WalletDB,
  dataStr: string,
  difficulty: uint16
) {.forceCheck: [
  ValueError
].} =
  var
    tip: Hash[256]
    data: Data
    wallet: HDWallet = db.wallet.external.first()
  try:
    tip = db.get(DATA_TIP()).toHash[:256]()
  except DBReadError:
    try:
      data = newData(Hash[256](), wallet.publicKey.serialize())
    except ValueError as e:
      panic("Failed to create an initial Data: " & e.msg)
    wallet.sign(data)
    data.mine(difficulty)
    db.put(DATA_TX(data.hash), data.serialize())
    db.put(DATA_TIP(), data.hash.serialize())
    tip = data.hash
  except ValueError as e:
    panic("WalletDB didn't save a 32-byte hash as the Data tip: " & e.msg)

  try:
    data = newData(tip, dataStr)
  except ValueError as e:
    raise e
  wallet.sign(data)
  data.mine(difficulty)
  db.put(DATA_TX(data.hash), data.serialize())
  db.put(DATA_TIP(), data.hash.serialize())

iterator loadDatasFromTip*(
  db: WalletDB
): Data {.forceCheck: [].} =
  var
    tip: Hash[256]
    done: bool = false
  try:
    tip = db.get(DATA_TIP()).toHash[:256]()
  except DBReadError:
    done = true
  except ValueError as e:
    panic("WalletDB didn't save a 32-byte hash as the Data tip: " & e.msg)

  while not done:
    var data: Data
    try:
      data = cast[Data](parseTransaction(tip, db.get(DATA_TX(tip))))
    except DBReadError as e:
      panic("Couldn't get Data " & $tip & " mentioned in the Wallet DB: " & e.msg)
    except ValueError as e:
      panic("Couldn't load a Data from the WalletDB: " & e.msg)
    yield data

    if data.inputs[0].hash == Hash[256]():
      done = true
    tip = data.inputs[0].hash

#Mark that we're verifying a Transaction.
#Assumes if the function completes, the input was used.
#If the function doesn't complete, none of its data is written.
proc verifyTransaction*(
  db: WalletDB,
  tx: MerosTransaction
) {.forceCheck: [
  ValueError
].} =
  #If we've already verified a Transaction sharing any inputs, raise.
  if not (
    (tx of Data) and
    (cast[Data](tx).isFirstData or (tx.inputs[0].hash == db.genesis))
  ):
    for input in tx.inputs:
      if db.verified.hasKey(input.serialize()):
        raise newLoggedException(ValueError, "Attempted to verify a competing Transaction.")

  var items: seq[tuple[key: string, value: string]] = newSeq[tuple[key: string, value: string]]()
  for input in tx.inputs:
    #Ignore initial Data inputs.
    if input.hash == Hash[256]():
      continue

    #Save the input to the nonce.
    items.add((INPUT_NONCE(db.unfinalizedNonces), char(0) & input.serialize()))
    db.verified[input.serialize()] = db.unfinalizedNonces
    inc(db.unfinalizedNonces)
  #Save the nonce count.
  items.add((UNFINALIZED_NONCES(), db.unfinalizedNonces.toBinary()))
  db.put(items)

#Get a nonce for use in an Element.
#Unable to assume if the function completes, the nonce was used.
#The nonce may have been used or may not have been.
#Best case in that circumstance is a halted Element chain; worst case is a Merit Removal.
proc getNonce*(
  db: WalletDB
): int {.forceCheck: [].} =
  db.put(USING_ELEMENT_NONCE(), "")
  result = db.elementNonce
  inc(db.elementNonce)
  db.put(ELEMENT_NONCE(), db.elementNonce.toBinary())

proc useNonce*(
  db: WalletDB
) {.forceCheck: [].} =
  db.del(USING_ELEMENT_NONCE())

proc delMinerNick*(
  db: WalletDB
) {.forceCheck: [].} =
  db.miner.nick = 0
  db.miner.initiated = false
  try:
    #Read it to check its existence.
    #WalletDB del panics if the key doesn't exist.
    discard db.get(MINER_NICK())
    db.del(MINER_NICK())
  except DBReadError:
    #Key doesn't exist; do nothing.
    discard
