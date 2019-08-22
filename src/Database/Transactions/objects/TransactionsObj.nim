#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Wallet libs.
import ../../../Wallet/MinerWallet
import ../../../Wallet/Wallet

#Consensus lib.
import ../../Consensus/Consensus

#Merit lib.
import ../../Merit/Merit

#Transactions DB lib.
import ../../Filesystem/DB/TransactionsDB

#Difficulties object.
import DifficultiesObj

#Transaction lib.
import ../Transaction as TransactionFile

#Tables standard library.
import tables

type
    Transactions* = object
        #DB Function Box.
        db: DB

        #Send/Data difficulties.
        difficulties*: Difficulties
        #Mint Nonce.
        mintNonce*: uint32

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

        #Table of inputs to whoever first spent them.
        spent*: Table[
            string,
            Hash[384]
        ]

#Helper functions to convert an input to a string.
proc toString*(
    input: Input,
    inputTX: Transaction
): string {.forceCheck: [].} =
    case inputTX:
        of Mint as _:
            discard
        of Claim as _:
            result = input.hash.toString()
        of Send as _:
            result = input.hash.toString() & char(cast[SendInput](input).nonce)
        of Data as _:
            result = input.hash.toString()

#Add a Transaction to the DAG.
proc add*(
    transactions: var Transactions,
    tx: Transaction,
    save: bool = true
) {.forceCheck: [].} =
    if not (tx of Mint):
        #Extract the hash.
        var hash: string = tx.hash.toString()

        #Add the Transaction to the cache.
        transactions.transactions[hash] = tx
        #Set its weight to 0.
        transactions.weights[hash] = 0

    if save:
        #Save the TX.
        transactions.db.save(tx)

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
        #Properties of each Verifier.
        key: BLSPublicKey
        outOfEpochs: int
        height: int
        elements: seq[Element]

        #Hashes of the TXs to reload.
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
            if element of Verification:
                hashes[cast[Verification](element).hash.toString()] = cast[Verification](element).hash

    #Load each transaction.
    var claims: seq[string] = @[]
    for hash in hashes.keys():
        if not result.transactions.hasKey(hash):
            try:
                result.add(db.load(hashes[hash]), false)
            except KeyError:
                doAssert(false, "Couldn't get a value by a key produced from .keys().")
            except DBReadError as e:
                doAssert(false, "Couldn't load a Transaction from the Database: " & e.msg)

            try:
                if result.transactions[hash] of Claim:
                    claims.add(hash)
            except KeyError as e:
                doAssert(false, "Couldn't get a value we just added: " & e.msg)

    #Recalculate the output amount for every Claim.
    var
        claim: Claim
        amount: uint64 = 0
    for claimHash in claims:
        try:
            claim = cast[Claim](result.transactions[claimHash])
        except KeyError as e:
            doAssert(false, "Couldn't get a Claim we just reloaded: " & e.msg)

        amount = 0
        for input in claim.inputs:
            try:
                amount += result[input.hash].outputs[0].amount
            except IndexError as e:
                doAssert(false, "Saved Claim couldn't be loaded from the cache or the DB: " & e.msg)
        try:
            claim.outputs[0].amount = amount
        except FinalAttributeError as e:
            doAssert(false, "Set a final attribute twice when reloading a Claim: " & e.msg)

#Load a Public Key's UTXOs.
proc getUTXOs*(
    transactions: Transactions,
    key: EdPublicKey
): seq[SendInput] {.forceCheck: [].} =
    try:
        result = transactions.db.loadSpendable(key)
    except DBReadError:
        result = @[]

#Save a Transaction. Do not apply any other checks.
proc saveTransaction*(
    transactions: Transactions,
    tx: Transaction
) {.inline, forceCheck: [].} =
    transactions.db.save(tx)

#Save a mint nonce.
proc saveMintNonce*(
    transactions: Transactions
) {.forceCheck: [].} =
    transactions.db.saveMintNonce(transactions.mintNonce)

#Mark a Transaction as verified.
proc verify*(
    transaction: Transactions,
    hash: Hash[384]
) {.forceCheck: [].} =
    transaction.db.saveVerified(hash)

#Save a MeritHolder's out-of-Epoch tip.
proc save*(
    transactions: Transactions,
    key: BLSPublicKey,
    nonce: int
) {.forceCheck: [].} =
    transactions.db.save(key, nonce)

#Save a Mint UTXO.
proc saveUTXO*(
    transactions: Transactions,
    hash: Hash[384],
    utxo: MintOutput
) {.forceCheck: [].} =
    transactions.db.save(hash, utxo)

#Save Send UTXOs.
proc saveUTXOs*(
    transactions: Transactions,
    hash: Hash[384],
    utxos: seq[SendOutput]
) {.forceCheck: [].} =
    transactions.db.save(hash, utxos)

#Save a sender's last Data.
proc saveData*(
    transactions: Transactions,
    sender: EdPublicKey,
    hash: Hash[384]
) {.forceCheck: [].} =
    try:
        transactions.db.saveData(sender, hash)
    except DBReadError as e:
        doAssert(false, "Couldn't parse the sender's previous Data from the Database: " & e.msg)

#Spend a Mint UTXO.
proc spend*(
    transactions: Transactions,
    hash: Hash[384]
) {.forceCheck: [].} =
    transactions.db.deleteUTXO(hash)

#Spend a Send UTXO.
proc spend*(
    transactions: Transactions,
    input: SendInput
) {.forceCheck: [].} =
    try:
        transactions.db.deleteUTXO(input.hash, input.nonce)
    except DBReadError as e:
        doAssert(false, "Trying to delete a deleted UTXO: " & e.msg)

#Delete a hash from the cache.
func del*(
    transactions: var Transactions,
    hash: string
) {.forceCheck: [].} =
    #Grab the transaction.
    var tx: Transaction
    try:
        tx = transactions.transactions[hash]
    except KeyError:
        return

    #Delete the Transaction from the cache.
    transactions.transactions.del(hash)
    #Delete its weight.
    transactions.weights.del(hash)

    #Clear the spent inputs.
    for input in tx.inputs:
        transactions.spent.del(input.toString(tx))

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

#Load a Mint UTXO.
proc loadUTXO*(
    transactions: Transactions,
    tx: Hash[384]
): MintOutput {.forceCheck: [
    DBReadError
].} =
    try:
        result = transactions.db.loadMintUTXO(tx)
    except DBReadError as e:
        fcRaise e

#Load a Send UTXO.
proc loadUTXO*(
    transactions: Transactions,
    input: SendInput
): SendOutput {.forceCheck: [
    DBReadError
].} =
    try:
        result = transactions.db.loadSendUTXO(input.hash, input.nonce)
    except DBReadError as e:
        fcRaise e

#Check if a sender has a Data.
proc loadData*(
    transactions: Transactions,
    sender: EdPublicKey
): Hash[384] {.forceCheck: [
    DBReadError
].} =
    try:
        result = transactions.db.loadData(sender)
    except DBReadError as e:
        fcRaise e

#Load the sender of a tip Data.
proc loadSender*(
    transactions: Transactions,
    data: Hash[384]
): EdPublicKey {.forceCheck: [
    DBReadError
].} =
    try:
        result = transactions.db.loadSender(data)
    except DBReadError as e:
        fcRaise e
