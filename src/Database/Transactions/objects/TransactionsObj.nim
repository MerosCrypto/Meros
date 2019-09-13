#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Wallet libs.
import ../../../Wallet/MinerWallet
import ../../../Wallet/Wallet

#MeritHolderRecord object.
import ../../common/objects/MeritHolderRecordObj

#Element and MeritHolder libs.
import ../../Consensus/Element
import ../../Consensus/MeritHolder

#Consensus object.
import ../../Consensus/objects/ConsensusObj

#Block and Blockchain libs.
import ../../Merit/Block
import ../../Merit/Blockchain

#Transactions DB lib.
import ../../Filesystem/DB/TransactionsDB

#Transaction lib.
import ../Transaction as TransactionFile

#Tables standard library.
import tables

type
    Transactions* = object
        #DB Function Box.
        db: DB

        #Mint Nonce.
        mintNonce*: uint32

        #Transactions which have yet to leave Epochs.
        transactions*: Table[Hash[384], Transaction]

#Get a Data's sender.
proc getSender*(
    transactions: var Transactions,
    data: Data
): EdPublicKey {.forceCheck: [
    DataMissing
].} =
    if data.isFirstData:
        try:
            return newEdPublicKey(cast[string](data.inputs[0].hash.data[16 ..< 48]))
        except EdPublicKeyError as e:
            doAssert(false, "Couldn't grab an EdPublicKey from a Data's input: " & e.msg)
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
    hash: Hash[384]
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
    consensus: Consensus,
    blockchain: Blockchain
): Transactions {.forceCheck: [].} =
    #Create the object.
    result = Transactions(
        db: db,

        mintNonce: 0,

        transactions: initTable[Hash[384], Transaction]()
    )

    #Load the mint nonce.
    try:
        result.mintNonce = db.loadMintNonce()
    except DBReadError:
        discard

    #Load the transactions from the DB.
    #Find every Verifier with a Verification still in Epochs.
    var mentioned: Table[BLSPublicKey, bool] = initTable[BLSPublicKey, bool]()
    try:
        for nonce in max(0, blockchain.height - 5) ..< blockchain.height:
            for record in blockchain[nonce].records:
                mentioned[record.key] = true
    except IndexError as e:
        doAssert(false, "Couldn't load records from the Blockchain while reloading Transactions: " & e.msg)

    #Go through each Verifier.
    var
        #Properties of each Verifier.
        outOfEpochs: int
        height: int
        elements: seq[Element]

        #Hashes of the TXs to reload.
        hashes: Table[Hash[384], bool]
    for key in mentioned.keys():
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
            if element of Verification:
                hashes[cast[Verification](element).hash] = true

    #Load every Transaction.
    for hash in hashes.keys():
        if not result.transactions.hasKey(hash):
            try:
                result.add(db.load(hash), false)
            except KeyError:
                doAssert(false, "Couldn't get a value by a key produced from .keys().")
            except DBReadError as e:
                doAssert(false, "Couldn't load a Transaction from the Database: " & e.msg)

#Load a Public Key's UTXOs.
proc getUTXOs*(
    transactions: Transactions,
    key: EdPublicKey
): seq[SendInput] {.forceCheck: [].} =
    try:
        result = transactions.db.loadSpendable(key)
    except DBReadError:
        result = @[]

#Save a MeritHolder's out-of-Epoch tip.
proc save*(
    transactions: Transactions,
    key: BLSPublicKey,
    nonce: int
) {.forceCheck: [].} =
    transactions.db.save(key, nonce)

#Mark a Transaction as verified, removing the outputs it spends from spendable.
proc verify*(
    transactions: var Transactions,
    hash: Hash[384]
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
    hash: Hash[384]
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
    hash: Hash[384]
) {.forceCheck: [].} =
    #Grab the transaction.
    var tx: Transaction
    try:
        tx = transactions.transactions[hash]
    except KeyError:
        return

    #Delete the Transaction from the cache.
    transactions.transactions.del(hash)

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

#Load a Mint Output.
proc loadOutput*(
    transactions: Transactions,
    tx: Hash[384]
): MintOutput {.forceCheck: [
    DBReadError
].} =
    try:
        result = transactions.db.loadMintOutput(tx)
    except DBReadError as e:
        fcRaise e

#Load a Send Output.
proc loadOutput*(
    transactions: Transactions,
    input: SendInput
): SendOutput {.forceCheck: [
    DBReadError
].} =
    try:
        result = transactions.db.loadSendOutput(input)
    except DBReadError as e:
        fcRaise e

proc loadSpenders*(
    transactions: Transactions,
    input: Input
): seq[Hash[384]] {.inline, forceCheck: [].} =
    transactions.db.loadSpenders(input)

#Load a Data Tip.
proc loadDataTip*(
    transactions: Transactions,
    key: EdPublicKey
): Hash[384] {.forceCheck: [].} =
    try:
        result = transactions.db.loadDataTip(key)
    except DBReadError:
        result = Hash[384]()
        for b in 16 ..< 48:
            result.data[b] = uint8(key.data[b - 16])
