#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Consensus lib.
import ../../Consensus/Consensus

#Merit lib.
import ../../Merit/Merit

#Transactions DB lib.
import ../../Filesystem/DB/TransactionsDB

#Difficulties object.
import DifficultiesObj

#Transaction object.
import TransactionObj

#Tables standard library.
import tables

type
    Transactions* = object
        #DB Function Box.
        db: DB

        #Send/Data difficulties.
        difficulties*: Difficulties
        #Mint Nonce.
        mintNonce*: int

        #Transactions which have yet to leave Epochs.
        transactions*: Table[
            string,
            Transaction
        ]
        #Hash -> Amount of Merit behind it.
        weights*: Table[
            string,
            int
        ]

#Add a Transaction to the DAG.
proc add*(
    transactions: var Transactions,
    tx: Transaction,
    save: bool = true
) {.forceCheck: [].} =
    #Extract the hash.
    var hash: string = tx.hash.toString()

    #Add the Transaction to the cache.
    transactions.transactions[hash] = tx
    #Set its weight to 0.
    transactions.weights[hash] = 0

    if save:
        #Save the TX.
        try:
            transactions.db.save(tx)
        except DBWriteError as e:
            doAssert(false, "Couldn't save a Transaction to the Database: " & e.msg)

#Transactions constructor
proc newTransactionsObj*(
    db: DB,
    consensus: Consensus,
    merit: Merit,
    sendDiff: string,
    dataDiff: string
): Transactions {.forceCheck: [].} =
    #Create the object.
    result = Transactions(
        db: db,

        difficulties: newDifficultiesObj(sendDiff, dataDiff),
        mintNonce: 0,

        transactions: initTable[string, Transaction](),
        weights: initTable[string, int]()
    )

    #Load the mint nonce.
    try:
        result.mintNonce = db.loadMintNonce()
    except DBReadError:
        discard

    #Load the transactions from the DB.
    #Find every Verifier with a Verification still in Epochs.
    var mentioned: Table[string, BLSPublicKey] = initTable[string, BLSPublicKey]()
    try:
        for nonce in max(0, merit.blockchain.height - 5) ..< merit.blockchain.height:
            for record in merit.blockchain[nonce].records:
                mentioned[record.key.toString()] = record.key
    except IndexError as e:
        doAssert(false, "Couldn't load records from the Blockchain while reloading Transactions: " & e.msg)

    #Go through each Verifier.
    var
        key: BLSPublicKey
        outOfEpochs: int
        height: int
        elements: seq[Verification]
        hashes: Table[string, Hash[384]]
    for keyStr in mentioned.keys():
        try:
            key = mentioned[keyStr]
        except KeyError:
            doAssert(false, "Couldn't get a value by a key produced from .keys().")

        #Find out what slice we're working with.
        try:
            outOfEpochs = db.load(key)
        except DBReadError:
            outOfEpochs = -1
        height = consensus[key].height

        try:
            elements = consensus[key][(outOfEpochs + 1) ..< height]
        except IndexError as e:
            doAssert(false, "Couldn't load elements from a MeritHolder while reloading Transactions: " & e.msg)
        for element in elements:
            hashes[element.hash.toString()] = element.hash

    #Load each transaction.
    for hash in hashes.keys():
        try:
            result.add(db.load(hashes[hash]), false)
        except KeyError:
            doAssert(false, "Couldn't get a value by a key produced from .keys().")
        except DBReadError as e:
            doAssert(false, "Couldn't load a Transaction from the Database: " & e.msg)

#Save a MeritHolder's out-of-Epoch tip.
proc save*(
    transactions: Transactions,
    key: BLSPublicKey,
    nonce: int
) {.forceCheck: [
    DBWriteError
].} =
    try:
        transactions.db.save(key, nonce)
    except DBWriteError as e:
        fcRaise e

#Save a Mint UTXO.
proc saveUTXO*(
    transactions: Transactions,
    hash: Hash[384],
    utxo: MintOutput
) {.forceCheck: [].} =
    try:
        transactions.db.save(hash, utxo)
    except DBWriteError as e:
        doAssert(false, "Couldn't save a Mint UTXO to the Database: " & e.msg)

#Save Send UTXOs.
proc saveUTXOs*(
    transactions: Transactions,
    hash: Hash[384],
    utxos: seq[SendOutput]
) {.forceCheck: [].} =
    try:
        transactions.db.save(hash, utxos)
    except DBWriteError as e:
        doAssert(false, "Couldn't save Send UTXOs to the Database: " & e.msg)

#Spend a Mint UTXO.
proc spend*(
    transactions: Transactions,
    hash: Hash[384]
) {.forceCheck: [].} =
    try:
        transactions.db.deleteUTXO(hash)
    except DBWriteError as e:
        doAssert(false, "Couldn't delete a Mint UTXO to the Database: " & e.msg)

#Spend a Send UTXO.
proc spend*(
    transactions: Transactions,
    input: SendInput
) {.forceCheck: [].} =
    try:
        transactions.db.deleteUTXO(input.hash, input.nonce)
    except DBWriteError as e:
        doAssert(false, "Couldn't delete a Send UTXO to the Database: " & e.msg)

#Delete a hash from the cache.
func del*(
    transactions: var Transactions,
    hash: string
) {.forceCheck: [].} =
    #Delete the Transaction from the cache.
    transactions.transactions.del(hash)
    #Delete its weight.
    transactions.weights.del(hash)

#Load a MeritHolder's out-of-Epoch tip.
proc load*(
    transactions: Transactions,
    key: BLSPublicKey
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = transactions.db.load(key)
    except DBReadError as e:
        fcRaise e

#Get a Transaction by its hash.
proc `[]`*(
    transactions: Transactions,
    hash: Hash[384]
): Transaction {.forceCheck: [
    IndexError
].} =
    #Extract the hash.
    var hashStr: string = hash.toString()

    #Check if the Transaction is in the cache.
    if transactions.transactions.hasKey(hashStr):
        #If it is, return it from the cache.
        try:
            return transactions.transactions[hashStr]
        except KeyError as e:
            doAssert(false, "Couldn't grab a Transaction despite confirming the key exists: " & e.msg)

    #Load the hash from the DB.
    try:
        result = transactions.db.load(hash)
    except DBReadError:
        raise newException(IndexError, "Hash doesn't map to any Transaction.")

#Get a Mint UTXO.
proc getUTXO*(
    transactions: Transactions,
    tx: Hash[384]
): MintOutput {.forceCheck: [
    DBReadError
].} =
    try:
        result = transactions.db.loadMintUTXO(tx)
    except DBReadError as e:
        fcRaise e

#Get a Send UTXO.
proc getUTXO*(
    transactions: Transactions,
    input: SendInput
): SendOutput {.forceCheck: [
    DBReadError
].} =
    try:
        result = transactions.db.loadSendUTXO(input.hash, input.nonce)
    except DBReadError as e:
        fcRaise e
