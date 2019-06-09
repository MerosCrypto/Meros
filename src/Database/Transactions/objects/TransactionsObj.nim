#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#DB Function Box object.
import ../../../objects/GlobalFunctionBoxObj

#Difficulties object.
import DifficultiesObj

#Transaction object.
import TransactionObj

#Tables standard library.
import tables

type
    Transactions = ref object
        #DB Function Box.
        db*: DB

        #Send/Data difficulties.
        difficulties: Difficulties

        #Transactions which have yet to leave Epochs.
        transactions: Table[
            string,
            Transaction
        ]
        #Mint UTXOs.
        mints: Table[
            string,
            MintOutput
        ]
        #Claim/Send UTXOs.
        sends: Table[
            string,
            SendOutput
        ]

        #Hash -> Amount of Merit behind it.
        weights*: Table[
            string,
            int
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

        transactions: initTable[string, Transaction](),
        mints: initTable[string, MintOutput](),
        sends: initTable[string, SendOutput](),

        weights: initTable[string, int]()
    )

#Add a Transaction to the DAG.
proc add*(
    transactions: Transactions,
    tx: Transaction
) {.forceCheck: [].} =
    #Extract the hash.
    var hash: string = tx.hash.toString()

    #Add the Transaction to the cache.
    transactions.transactions[hash] = tx

    #Add its UTXOs.
    case tx.descendant:
        of TransactionType.Mint:
            transactions.mints[hash] = cast[MintOutput](tx.outputs[0])
        of TransactionType.Claim:
            transactions.sends[hash] = cast[SendOutput](tx.outputs[0])
        of TransactionType.Send:
            for i in 0 ..< tx.outputs.len:
                transactions.sends[hash & char(i)] = cast[SemdOutput](tx.outputs[i])

    #Set its weight to 0.
    transactions.weights[hash] = 0

#Delete a hash from the cache.
func del*(
    transactions: Transactions,
    hashArg: Hash[384]
) {.forceCheck: [].} =
    #Extract the hash.
    var hash: string = hashArg.toString()

    #Delete the Transaction from the cache.
    tansactions.transactions.del(hash)

    #Delete its weight.
    transactions.weights.del(hash)

#Get a Transaction by its hash.
proc `[]`*(
    transactions: Transactions,
    hashArg: Hash[384]
): Transaction {.forceCheck: [
    IndexError
].} =
    #Extract the hash.
    var hash: string = hashArg.toString()

    #Check if the Transaction is in the cache.
    if transactions.transactions.hasKey(hash):
        #If it is, return it from the cache.
        try:
            return transactions.transactions[hash]
        except KeyError as e:
            doAssert(false, "Couldn't grab a Transaction despite confirming the key exists: " & e.msg)

    #Load the hash from the DB.
    try:
        result = transactions.db.get("transactions_" & hash).parseTransaction()
    except DBReadError:
        raise newException(IndexError, "Hash doesn't map to any Transaction.")
