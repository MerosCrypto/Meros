#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

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

        #Mint UTXOs.
        mints*: Table[
            string,
            MintOutput
        ]
        #Claim/Send UTXOs.
        sends*: Table[
            string,
            SendOutput
        ]

#Transactions constructor
proc newTransactionsObj*(
    db: DB,
    sendDiff: string,
    dataDiff: string
): Transactions {.forceCheck: [].} =
    #Create the object.
    result = Transactions(
        db: db,

        difficulties: newDifficultiesObj(sendDiff, dataDiff),
        mintNonce: 0,

        transactions: initTable[string, Transaction](),
        weights: initTable[string, int](),

        mints: initTable[string, MintOutput](),
        sends: initTable[string, SendOutput]()
    )

#Add a Transaction to the DAG.
proc add*(
    transactions: var Transactions,
    tx: Transaction
) {.forceCheck: [].} =
    #Extract the hash.
    var hash: string = tx.hash.toString()

    #Add the Transaction to the cache.
    transactions.transactions[hash] = tx
    #Set its weight to 0.
    transactions.weights[hash] = 0

    #Save the TX.
    transactions.db.save(tx)

#Delete a hash from the cache.
func del*(
    transactions: var Transactions,
    hashArg: Hash[384]
) {.forceCheck: [].} =
    #Extract the hash.
    var hash: string = hashArg.toString()

    #Delete the Transaction from the cache.
    transactions.transactions.del(hash)
    #Delete its weight.
    transactions.weights.del(hash)

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
