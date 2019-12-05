#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet
import ../../Wallet/MinerWallet

#Blockchain and Epochs libs.
import ../Merit/Blockchain
import ../Merit/Epochs

#Transactions DB lib.
import ../Filesystem/DB/TransactionsDB

#Transaction lib.
import Transaction
export Transaction

#Transactions object.
import objects/TransactionsObj
export TransactionsObj.Transactions, `[]`
export toString, getUTXOs, loadSpenders, loadDataTip, verify, unverify

#Seq utils standard lib.
import sequtils

#Sets standard lib.
import sets

#Tables standard lib.
import tables

#Constructor.
proc newTransactions*(
    db: DB,
    blockchain: Blockchain
): Transactions {.inline, forceCheck: [].} =
    newTransactionsObj(db, blockchain)

#Add a Claim.
proc add*(
    transactions: var Transactions,
    claim: Claim,
    lookup: proc (
        holder: uint16
    ): BLSPublicKey {.raises: [
        IndexError
    ].}
) {.forceCheck: [
    ValueError,
    DataExists
].} =
    #Verify it wasn't already added.
    try:
        discard transactions[claim.hash]
        raise newException(DataExists, "Claim was already added.")
    except IndexError:
        discard

    var
        #Claimers.
        claimers: seq[BLSPublicKey] = newSeq[BLSPublicKey](1)

        #Table of spent inputs.
        inputTable: HashSet[string] = initHashSet[string]()
        #Output loop variable.
        output: MintOutput
        #Key loop variable.
        key: BLSPublicKey
        #Amount this Claim is claiming.
        amount: uint64 = 0

    #Grab the first claimer.
    try:
         claimers[0] = lookup(transactions.loadOutput(claim.inputs[0].hash).key)
    except IndexError as e:
        doAssert(false, "Created a Mint to a non-existent Merit Holder: " & e.msg)
    except DBReadError:
        raise newException(ValueError, "Claim spends a non-existant Mint.")

    #Add the amount the inputs provide. Also verify no inputs are spent multiple times.
    for input in claim.inputs:
        if inputTable.contains(input.toString()):
            raise newException(ValueError, "Claim spends the same input twice.")
        inputTable.incl(input.toString())

        try:
            if not (transactions[input.hash] of Mint):
                raise newException(ValueError, "Claim doesn't spend a Mint.")
        except IndexError:
            raise newException(ValueError, "Claim spends a non-existant Mint.")

        try:
            output = transactions.loadOutput(input.hash)
        except DBReadError:
            raise newException(ValueError, "Claim spends a non-existant Mint.")

        try:
            key = lookup(output.key)
        except IndexError as e:
            doAssert(false, "Created a Mint to a non-existent Merit Holder: " & e.msg)

        if not claimers.contains(key):
            claimers.add(key)
        amount += output.amount

    #Set the Claim's output amount to the amount.
    try:
        claim.outputs[0].amount = amount
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when adding a Claim: " & e.msg)

    #Verify the signature.
    try:
        if not claim.verify(claimers.aggregate()):
            raise newException(ValueError, "Claim has an invalid Signature.")
    except BLSError as e:
        doAssert(false, "Failed to aggregate BLS Public Keys: " & e.msg)

    #Add the Claim.
    transactions.add(cast[Transaction](claim))

#Add a Send.
proc add*(
    transactions: var Transactions,
    send: Send
) {.forceCheck: [
    ValueError,
    DataExists
].} =
    #Verify it wasn't already added.
    try:
        discard transactions[send.hash]
        raise newException(DataExists, "Send was already added.")
    except IndexError:
        discard

    #Verify the inputs length.
    if send.inputs.len < 1 or 255 < send.inputs.len:
        raise newException(ValueError, "Send has too little or too many inputs.")
    #Verify the outputs length.
    if send.outputs.len < 1 or 255 < send.outputs.len:
        raise newException(ValueError, "Send has too little or too many outputs.")

    var
        #Sender.
        senders: seq[EdPublicKey] = newSeq[EdPublicKey](1)

        #Table of spent inputs.
        inputTable: HashSet[string] = initHashSet[string]()
        #Spent output loop variable.
        spent: SendOutput
        #Amount this transaction is processing.
        amount: uint64 = 0

    #Grab the first sender.
    try:
        senders[0] = transactions.loadOutput(cast[SendInput](send.inputs[0])).key
    except DBReadError:
        raise newException(ValueError, "Send spends a non-existant output.")

    #Add the amount the inputs provide. Also verify no inputs are spent multiple times.
    for input in send.inputs:
        if inputTable.contains(input.toString()):
            raise newException(ValueError, "Send spends the same input twice.")
        inputTable.incl(input.toString())

        try:
            if (
                (not (transactions[input.hash] of Claim)) and
                (not (transactions[input.hash] of Send))
            ):
                raise newException(ValueError, "Send doesn't spend a Claim or Send.")
        except IndexError:
            raise newException(ValueError, "Send spends a non-existant Claim or Send.")

        try:
            spent = transactions.loadOutput(cast[SendInput](input))
        except DBReadError:
            raise newException(ValueError, "Send spends a non-existant output.")

        if not senders.contains(spent.key):
            senders.add(spent.key)

        amount += spent.amount

    #Subtract the amount the outpts spend.
    for output in send.outputs:
        if output.amount == 0:
            raise newException(ValueError, "Send output has an amount of 0.")

        amount -= output.amount

    #If the amount is not 9, there's a problem
    #It should be noted, amount can underflow. It's impossible to spend the full underflow.
    if amount != 0:
        raise newException(ValueError, "Send outputs don't spend the amount provided by the inputs.")

    #Verify the signature.
    if not senders.aggregate().verify(send.hash.toString(), send.signature):
        raise newException(ValueError, "Send has an invalid Signature.")

    #Add the Send.
    transactions.add(cast[Transaction](send))

#Add a Data.
proc add*(
    transactions: var Transactions,
    data: Data
) {.forceCheck: [
    ValueError,
    DataExists
].} =
    #Verify the Data's hash doesn't start with 16 zeroes.
    for b in 0 ..< 16:
        if data.hash.data[b] != 0:
            break
        if b == 15:
            raise newException(ValueError, "Data's hash starts with 16 0s.")

    #Verify it wasn't already added.
    try:
        discard transactions[data.hash]
        raise newException(DataExists, "Data was already added.")
    except IndexError:
        discard

    #Verify the inputs length.
    if data.inputs.len != 1:
        raise newException(ValueError, "Data doesn't have one input.")

    #Load the sender (which also verifies the input exists, if it's not the sender's key).
    var sender: EdPublicKey
    try:
        sender = transactions.getSender(data)
    except DataMissing as e:
        raise newException(ValueError, "Data's input is either missing or not a Data: " & e.msg)

    #Verify the signature.
    if not sender.verify(data.hash.toString(), data.signature):
        raise newException(ValueError, "Data has an invalid Signature.")

    #Add the Data.
    transactions.add(cast[Transaction](data))

#Mint Meros to the specified key.
proc mint*(
    transactions: var Transactions,
    nick: uint16,
    amount: uint64
): Hash[384] {.forceCheck: [].} =
    #Create the Mint.
    var mint: Mint = newMint(
        transactions.mintNonce,
        nick,
        amount
    )

    #Add it to Transactions.
    transactions.add(cast[Transaction](mint))

    #Increment the mint nonce.
    inc(transactions.mintNonce)

    #Return the mint hash.
    result = mint.hash

#Remove every hash in this Epoch from the cache/RAM.
proc archive*(
    transactions: var Transactions,
    epoch: Epoch
) {.forceCheck: [].} =
    for hash in epoch.keys():
        transactions.del(hash)

#Check if a Transaction is the first to spend all its inputs.
proc isFirst*(
    transactions: Transactions,
    tx: Transaction
): bool {.forceCheck: [].} =
    for input in tx.inputs:
        try:
            if transactions.loadSpenders(input)[0] != tx.hash:
                return false
        except IndexError:
            doAssert(false, "Transaction spends non-existent input.")
    return true
