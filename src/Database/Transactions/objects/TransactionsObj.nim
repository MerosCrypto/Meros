#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Wallet libs.
import ../../../Wallet/MinerWallet
import ../../../Wallet/Wallet

#VerificationPacket object.
import ../../Consensus/Elements/objects/VerificationPacketObj

#Block and Blockchain libs.
import ../../Merit/Block
import ../../Merit/Blockchain

#Transactions DB lib.
import ../../Filesystem/DB/TransactionsDB

#Transaction lib.
import ../Transaction as TransactionFile

#Sets standard lib.
import sets

#Tables standard library.
import tables

type
    Transactions* = object
        #DB Function Box.
        db: DB
        #Transactions which have yet to leave Epochs.
        transactions*: Table[Hash[256], Transaction]

#Get a Data's sender.
proc getSender*(
    transactions: var Transactions,
    data: Data
): EdPublicKey {.forceCheck: [
    DataMissing
].} =
    if data.isFirstData:
        try:
            if data.data.len != 32:
                raise newException(DataMissing, "Initial data wasn't provided a public key.")
            return newEdPublicKey(data.data)
        except ValueError as e:
            doAssert(false, "Couldn't create an EdPublicKey from a Data's input: " & e.msg)
    else:
        try:
            return transactions.db.loadDataSender(data.inputs[0].hash)
        except DBReadError:
            raise newException(DataMissing, "Couldn't find the Data's input which was not its sender.")

#Add a Transaction to the DAG.
proc add*(
    transactions: var Transactions,
    tx: Transaction,
    save: bool = true
) {.forceCheck: [].} =
    if not (tx of Mint):
        #Add the Transaction to the cache.
        transactions.transactions[tx.hash] = tx

    if save:
        #Save the TX.
        transactions.db.save(tx)

        #If this is a Data, save the sender.
        if tx of Data:
            var data: Data = cast[Data](tx)
            try:
                transactions.db.saveDataSender(data, transactions.getSender(data))
            except DataMissing as e:
                doAssert(false, "Added a Data we don't know the sender of: " & e.msg)

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
            doAssert(false, "Couldn't grab a Transaction despite confirming the key exists: " & e.msg)

    #Load the hash from the DB.
    try:
        result = transactions.db.load(hash)
    except DBReadError:
        raise newException(IndexError, "Hash doesn't map to any Transaction.")

#Transactions constructor.
proc newTransactionsObj*(
    db: DB,
    blockchain: Blockchain
): Transactions {.forceCheck: [].} =
    #Create the object.
    result = Transactions(
        db: db,
        transactions: initTable[Hash[256], Transaction]()
    )

    #Load the Transactions from the DB.
    var mentioned: HashSet[Hash[256]] = initHashSet[Hash[256]]()
    try:
        #Find which Transactions were mentioned before the last 5 blocks.
        for b in max(0, blockchain.height - 10) ..< blockchain.height - 5:
            for packet in blockchain[b].body.packets:
                mentioned.incl(packet.hash)

        #Load Transactions in the last 5 Blocks, as long as they aren't first mentioned in older Blocks.
        for b in max(0, blockchain.height - 5) ..< blockchain.height:
            for packet in blockchain[b].body.packets:
                if mentioned.contains(packet.hash):
                    continue

                try:
                    result.add(db.load(packet.hash), false)
                except DBReadError as e:
                    doAssert(false, "Couldn't load a Transaction from the Database: " & e.msg)
                mentioned.incl(packet.hash)
    except IndexError as e:
        doAssert(false, "Couldn't load hashes from the Blockchain while reloading Transactions: " & e.msg)

#Load a Public Key's UTXOs.
proc getUTXOs*(
    transactions: Transactions,
    key: EdPublicKey
): seq[FundedInput] {.forceCheck: [].} =
    try:
        result = transactions.db.loadSpendable(key)
    except DBReadError:
        result = @[]

#Mark a Transaction as verified, removing the outputs it spends from spendable.
proc verify*(
    transactions: var Transactions,
    hash: Hash[256]
) {.forceCheck: [].} =
    var tx: Transaction
    try:
        tx = transactions[hash]
    except IndexError as e:
        doAssert(false, "Tried to mark a non-existent Transaction as verified: " & e.msg)

    case tx:
        of Claim as claim:
            transactions.db.verify(claim)
        of Send as send:
            transactions.db.verify(send)
        of Data as data:
            try:
                transactions.db.saveDataTip(transactions.getSender(data), data.hash)
            except DataMissing as e:
                doAssert(false, "Added and verified a Data which has a missing input: " & e.msg)
        else:
            discard

#Mark a Transaction as unverified, removing its outputs from spendable.
proc unverify*(
    transactions: var Transactions,
    hash: Hash[256]
) {.forceCheck: [].} =
    var tx: Transaction
    try:
        tx = transactions[hash]
    except IndexError as e:
        doAssert(false, "Tried to mark a non-existent Transaction as verified: " & e.msg)

    case tx:
        of Claim as claim:
            transactions.db.unverify(claim)
        of Send as send:
            transactions.db.unverify(send)
        of Data as data:
            try:
                transactions.db.saveDataTip(transactions.getSender(data), data.inputs[0].hash)
            except DataMissing as e:
                doAssert(false, "Added, verified, and unverified a Data which has a missing input: " & e.msg)
        else:
            discard

#Delete a hash from the cache.
func del*(
    transactions: var Transactions,
    hash: Hash[256]
) {.forceCheck: [].} =
    #Grab the transaction.
    var tx: Transaction
    try:
        tx = transactions.transactions[hash]
    except KeyError:
        return

    #Delete the Transaction from the cache.
    transactions.transactions.del(hash)

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

#Load a Data Tip.
proc loadDataTip*(
    transactions: Transactions,
    key: EdPublicKey
): Hash[256] {.forceCheck: [
    DataMissing
].} =
    try:
        result = transactions.db.loadDataTip(key)
    except DBReadError:
        raise newException(DataMissing, "Data tip not found.")
