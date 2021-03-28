import options
import tables

import mc_lmdb

import ../../../lib/[Errors, Util, Hash]
import ../../../Wallet/[MinerWallet, Wallet, Address]

import ../../Transactions/objects/TransactionObj
import ../../Transactions/Data as DataFile

import ../../Merit/objects/EpochsObj

import ../../../Network/Serialize/SerializeCommon

import ../DB/Serialize/Transactions/[DBSerializeTransaction, ParseTransaction]

template MNEMONIC(): string =
  "w"

template MINER_KEY(): string =
  "m"

template ACCOUNT_ZERO(): string =
  "az"

template CHAIN_CODE(): string =
  "cc"

template ADDRESS_COUNT(): string =
  "ac"

template DATA_TIP(): string =
  "d"

#_TX added so the symbol doesn't conflict with the Data type.
template DATA_TX(
  hash: Hash[256]
): string =
  "d" & hash.serialize()

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

    mnemonic: Mnemonic
    miner*: MinerWallet
    accountZero*: EdPublicKey
    chainCode*: Hash[256]
    addresses*: uint32

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
  #Data doesn't exist.
  except Exception:
    discard

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

      mnemonic: newWallet("").mnemonic,
      addresses: 0,

      finalizedNonces: 0,
      unfinalizedNonces: 0,
      verified: initTable[string, int](),

      elementNonce: 0
    )
    result.miner = newMinerWallet(result.mnemonic.unlock("")[0 ..< 32])
    let wallet: HDWallet = newWallet(result.mnemonic.sentence, "").hd[0]
    result.accountZero = wallet.publicKey
    result.chainCode = wallet.chainCode
    result.lmdb.open()
  except Exception as e:
    raise newLoggedException(DBError, "Couldn't open the WalletDB: " & e.msg)

  #Load the Wallets.
  try:
    result.mnemonic = newMnemonic(result.get(MNEMONIC()))
    result.miner = newMinerWallet(result.get(MINER_KEY()))
    result.accountZero = newEdPublicKey(result.get(ACCOUNT_ZERO()))
    result.chainCode = result.get(CHAIN_CODE()).toHash[:256]()
    result.addresses = cast[uint32](result.get(ADDRESS_COUNT()).fromBinary())
  except ValueError as e:
    panic("Failed to load the Wallet from the Database: " & e.msg)
  except BLSError as e:
    panic("Failed to load the MinerWallet from the Database: " & e.msg)
  except DBReadError:
    result.put(MNEMONIC(), $result.mnemonic)
    result.put(MINER_KEY(), result.miner.privateKey.serialize())
    result.put(ACCOUNT_ZERO(), result.accountZero.serialize())
    result.put(CHAIN_CODE(), result.chainCode.serialize())
    result.put(ADDRESS_COUNT(), 0.toBinary())

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

#Meant to encourage the non-usage of direct access by defining a getter returning its string form.
proc getMnemonic*(
  db: WalletDB
): string {.inline, forceCheck: [].} =
  $db.mnemonic

#Set the Wallet.
proc setWallet*(
  db: WalletDB,
  wallet: InsecureWallet,
  datas: seq[Data]
) {.forceCheck: [].} =
  #Update the DB instance.
  try:
    db.miner = newMinerWallet(wallet.mnemonic.unlock(wallet.password)[0 ..< 32])
  except BLSError as e:
    panic("Couldn't create a MinerWallet out of a 32-byte secret: " & e.msg)
  db.mnemonic = wallet.mnemonic
  try:
    let account: HDWallet = wallet.hd[0]
    db.accountZero = account.publicKey
    db.chainCode = account.chainCode
  except ValueError as e:
    panic("Unusable Wallet created and passed to setWallet: " & e.msg)

  var items: seq[tuple[key: string, value: string]] = @[]

  #Save the Mnemonic.
  items.add((key: MNEMONIC(), value: $db.mnemonic))

  #Save the miner.
  items.add((key: MINER_KEY(), value: db.miner.privateKey.serialize()))

  #Save the account key and chain code.
  items.add((key: ACCOUNT_ZERO(), value: db.accountZero.serialize()))
  items.add((key: CHAIN_CODE(), value: db.chainCode.serialize()))

  #Set the Datas.
  for data in datas:
    items.add((key: DATA_TX(data.hash), value: data.serialize()))

  #Update the Data tip.
  if datas.len != 0:
    items.add((key: DATA_TIP(), value: datas[0].hash.serialize()))
  else:
    items.add((key: DATA_TIP(), value: ""))

  #Actually commit all of this.
  db.put(items)

#Set our miner's nick.
proc setMinerNick*(
  db: WalletDB,
  nick: uint16
) {.forceCheck: [].} =
  db.miner.nick = nick
  db.miner.initiated = true
  db.put(MINER_KEY(), db.miner.privateKey.serialize())
  db.put(MINER_NICK(), nick.toBinary())

proc getAddress*(
  db: WalletDB,
  index: Option[uint32],
  used: proc (
    key: EdPublicKey
  ): bool {.gcsafe, raises: [].}
): string {.forceCheck: [
  ValueError
].} =
  var
    external: HDPublic
    child: HDPublic
  #Get the external chain.
  try:
    external = HDPublic(
      key: db.accountZero,
      chainCode: db.chainCode
    ).derivePublic(1)
  except ValueError as e:
    panic("WalletDB has an unusable Wallet: " & e.msg)

  #Get the child.
  if index.isSome():
    try:
      child = external.derivePublic(index.unsafeGet())
    except ValueError as e:
      raise e
  else:
    try:
      child = external.next(db.addresses)
    except ValueError as e:
      raise e

    #This will return the same address we returned last time.
    #We want to do that UNLESS this address was used in the mean time.
    while child.key.used:
      try:
        child = external.next(child.index + 1)
      except ValueError as e:
        raise e

    #Update the address count.
    db.addresses = child.index
    db.put(ADDRESS_COUNT(), db.addresses.toBinary())

  result = newAddress(AddressType.PublicKey, child.key.serialize())

proc unlock(
  db: WalletDB,
  password: string
): HDWallet {.forceCheck: [
  ValueError
].} =
  try:
    result = newHDWallet(SHA2_256(db.mnemonic.unlock(password)).serialize())[0]
    if result.publicKey != db.accountZero:
      raise newException(ValueError, "")
  except ValueError:
    raise newLoggedException(ValueError, "Invalid password.")

proc stepData*(
  db: WalletDB,
  password: string,
  dataStr: string,
  difficulty: uint16
) {.forceCheck: [
  ValueError
].} =
  var
    tip: Hash[256]
    data: Data
    wallet: HDWallet

  try:
    wallet = db.unlock(password).derive(1).first()
  except ValueError as e:
    raise e

  try:
    let storedTip: string = db.get(DATA_TIP())
    #Length is 0 when a new Wallet without Datas is set.
    if storedTip.len == 0:
      raise newException(DBReadError, "")
    tip = storedTip.toHash[:256]()
  except DBReadError:
    #If there isn't a data tip, create the initial Data.
    try:
      data = newData(Hash[256](), wallet.publicKey.serialize())
    except ValueError as e:
      panic("Failed to create an initial Data: " & e.msg)
    wallet.sign(data)
    data.mine(difficulty)
    db.put(DATA_TX(data.hash), data.serialize())
    db.put(DATA_TIP(), data.hash.serialize())
    tip = data.hash

  #Create this Data.
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
    let storedTip: string = db.get(DATA_TIP())
    if storedTip.len == 0:
      raise newException(DBReadError, "")
    tip = storedTip.toHash[:256]()
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
