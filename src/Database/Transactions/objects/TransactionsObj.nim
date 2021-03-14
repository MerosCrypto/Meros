import sets, tables

import ../../../lib/[Errors, Hash]
import ../../../Wallet/Wallet

import ../../Filesystem/DB/TransactionsDB

import ../../Consensus/Elements/objects/VerificationPacketObj

import ../../Merit/Blockchain

import FamilyManagerObj
export FamilyManagerObj

import ../Transaction as TransactionFile

type Transactions* = object
  db*: DB
  #Copy of the Genesis.
  genesis*: Hash[256]
  #Wallet used to sign/verify Datas created by Blocks.
  dataWallet*: HDWallet
  #Cache of transactions which have yet to leave Epochs.
  transactions*: Table[Hash[256], Transaction]
  #Family tracker:
  families*: FamilyManager

#Get a Data's sender.
proc getSender*(
  transactions: var Transactions,
  data: Data
): EdPublicKey {.forceCheck: [
  DataMissing
].} =
  if data.isFirstData:
    if data.data.len != 32:
      raise newLoggedException(DataMissing, "Initial data wasn't provided a public key.")
    result = newEdPublicKey(data.data)
  else:
    if data.inputs[0].hash == transactions.genesis:
      return transactions.dataWallet.publicKey
    try:
      result = transactions.db.loadDataSender(data.inputs[0].hash)
    except DBReadError:
      raise newLoggedException(DataMissing, "Couldn't find the Data's input which was not its sender.")

proc add*(
  transactions: var Transactions,
  tx: Transaction,
  save: bool = true
) {.forceCheck: [
  ValueError
].} =
  if save:
    #Verify every input doesn't have a spender out of Epochs.
    #When the Transaction is a Data, this has two exceptions.
    #If it's the first Data, it doesn't have a valid input.
    #If it's a Data created from a Block, the input is reused.
    if not ((tx of Data) and (cast[Data](tx).isFirstData or (tx.inputs[0].hash == transactions.genesis))):
      for input in tx.inputs:
        if transactions.db.isBeaten(input.hash):
          raise newLoggedException(ValueError, "Transaction spends a finalized Transaction which was beaten.")

        var spenders: seq[Hash[256]] = transactions.db.loadSpenders(input)
        if spenders.len == 0:
          continue
        if not transactions.transactions.hasKey(spenders[0]):
          raise newLoggedException(ValueError, "Transaction competes with a finalized Transaction.")

  if not (tx of Mint):
    #Add the Transaction to the cache.
    transactions.transactions[tx.hash] = tx

  if save:
    #Save the TX.
    transactions.db.save(tx)

    #If this is a Data, save the sender as well.
    if tx of Data:
      var data: Data = cast[Data](tx)
      try:
        transactions.db.saveDataSender(data, transactions.getSender(data))
      except DataMissing as e:
        panic("Added a Data we don't know the sender of: " & e.msg)

#Get a Transaction by its hash.
proc `[]`*(
  transactions: Transactions,
  hash: Hash[256]
): Transaction {.forceCheck: [
  IndexError
].} =
  #Check if the Transaction is in the cache.
  if transactions.transactions.hasKey(hash):
    #If it is, return it from the cache.
    try:
      return transactions.transactions[hash]
    except KeyError as e:
      panic("Couldn't grab a Transaction despite confirming the key exists: " & e.msg)

  #Load the hash from the DB.
  try:
    result = transactions.db.load(hash)
  except DBReadError:
    raise newLoggedException(IndexError, "Hash doesn't map to any Transaction.")

proc newTransactionsObj*(
  db: DB,
  blockchain: Blockchain
): Transactions {.forceCheck: [].} =
  result = Transactions(
    db: db,
    genesis: blockchain.genesis,
    transactions: initTable[Hash[256], Transaction](),
    families: newFamilyManager()
  )

  try:
    result.dataWallet = newWallet(result.db.loadDataWallet(), "").hd
  except ValueError as e:
    panic("Couldn't reload this node's Data Wallet: " & e.msg)
  except DBReadError:
    let wallet: InsecureWallet = newWallet("")
    result.dataWallet = wallet.hd
    result.db.saveDataWallet($wallet.mnemonic)

  #Load the Transactions from the DB.
  try:
    #Find which Transactions were mentioned before the last 5 blocks.
    var mentioned: HashSet[Hash[256]] = initHashSet[Hash[256]]()
    for b in max(0, blockchain.height - 10) ..< blockchain.height - 5:
      for packet in blockchain[b].body.packets:
        mentioned.incl(packet.hash)

    #Load Transactions in the last 5 Blocks, as long as they aren't first mentioned in older Blocks.
    for b in max(0, blockchain.height - 5) ..< blockchain.height:
      for packet in blockchain[b].body.packets:
        if mentioned.contains(packet.hash):
          continue

        try:
          var tx: Transaction = db.load(packet.hash)
          result.add(tx, false)
          result.families.register(tx.inputs)
        except ValueError as e:
          panic("Adding a reloaded Transaction raised a ValueError: " & e.msg)
        except DBReadError as e:
          panic("Couldn't load a Transaction from the Database: " & e.msg)
        mentioned.incl(packet.hash)

    #Load the unmentioned Transactions.
    for hash in db.loadUnmentioned():
      try:
        result.add(db.load(hash), false)
      except ValueError as e:
        panic("Adding a reloaded unmentioned Transaction raised a ValueError: " & e.msg)
      except DBReadError as e:
        panic("Couldn't load an unmentioned Transaction from the Database: " & e.msg)
  except IndexError as e:
    panic("Couldn't load hashes from the Blockchain while reloading Transactions: " & e.msg)

#Load a Public Key's UTXOs.
proc getUTXOs*(
  transactions: Transactions,
  key: EdPublicKey
): seq[FundedInput] {.forceCheck: [].} =
  try:
    result = transactions.db.loadSpendable(key)
  except DBReadError:
    result = @[]

#Mark a Transaction as mentioned.
proc mention*(
  transactions: Transactions,
  hash: Hash[256]
) {.inline, forceCheck: [].} =
  transactions.db.mention(hash)

#Mark a Transaction as verified, removing the outputs it spends from spendable.
proc verify*(
  transactions: var Transactions,
  hash: Hash[256]
) {.forceCheck: [].} =
  var tx: Transaction
  try:
    tx = transactions[hash]
  except IndexError as e:
    panic("Tried to mark a non-existent Transaction as verified: " & e.msg)

  transactions.db.verify(tx)

#Mark a Transaction as unverified, removing its outputs from spendable.
proc unverify*(
  transactions: var Transactions,
  hash: Hash[256]
) {.forceCheck: [].} =
  var tx: Transaction
  try:
    tx = transactions[hash]
  except IndexError as e:
    panic("Tried to mark a non-existent Transaction as verified: " & e.msg)

  transactions.db.unverify(tx)

#Mark a Transaction as beaten.
proc beat*(
  transactions: Transactions,
  hash: Hash[256]
) {.inline, forceCheck: [].} =
  transactions.db.beat(hash)

#Mark Transactions as unmentioned.
proc unmention*(
  transactions: Transactions,
  hashes: HashSet[Hash[256]]
) {.inline, forceCheck: [].} =
  transactions.db.unmention(hashes)

#Delete a hash from the cache.
func del*(
  transactions: var Transactions,
  hash: Hash[256]
) {.forceCheck: [].} =
  transactions.transactions.del(hash)

#Prune a Transaction.
proc prune*(
  transactions: var Transactions,
  hash: Hash[256]
) {.forceCheck: [].} =
  transactions.transactions.del(hash)
  transactions.db.prune(hash)

#Load a Mint Output.
proc loadMintOutput*(
  transactions: Transactions,
  input: FundedInput
): MintOutput {.forceCheck: [
  DBReadError
].} =
  try:
    result = transactions.db.loadMintOutput(input)
  except DBReadError as e:
    raise e

#Load a Claim or Send Output.
proc loadSendOutput*(
  transactions: Transactions,
  input: FundedInput
): SendOutput {.forceCheck: [
  DBReadError
].} =
  try:
    result = transactions.db.loadSendOutput(input)
  except DBReadError as e:
    raise e

proc loadSpenders*(
  transactions: Transactions,
  input: Input
): seq[Hash[256]] {.inline, forceCheck: [].} =
  transactions.db.loadSpenders(input)
