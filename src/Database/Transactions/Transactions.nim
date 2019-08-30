#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet
import ../../Wallet/MinerWallet

#Consensus lib.
import ../Consensus/Consensus

#Merit lib.
import ../Merit/Merit

#Transactions DB lib.
import ../Filesystem/DB/TransactionsDB

#MeritHolderRecord object.
import ../common/objects/MeritHolderRecordObj

#Transaction lib.
import Transaction
export Transaction

#Transactions object.
import objects/TransactionsObj
export TransactionsObj.Transactions, `[]`
export markVerified, getUTXOs, toString
#export loadData

#Seq utils standard lib.
import sequtils

#Tables standard lib.
import tables

#Constructor.
proc newTransactions*(
    db: DB,
    consensus: Consensus,
    merit: Merit
): Transactions {.inline, forceCheck: [].} =
    newTransactionsObj(
        db,
        consensus,
        merit
    )

#Add a Claim.
proc add*(
    transactions: var Transactions,
    claim: Claim
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

        #Output loop variable.
        output: MintOutput
        #Amount this Claim is claiming.
        amount: uint64 = 0

    #Grab the first claimer.
    try:
         claimers[0] = transactions.loadUTXO(claim.inputs[0].hash).key
    except DBReadError:
        raise newException(ValueError, "Claim spends a non-existant or spent Mint.")

    #Add the amount the inputs provide.
    for input in claim.inputs:
        try:
            output = transactions.loadUTXO(input.hash)
        except DBreadError:
            raise newException(ValueError, "Claim spends a non-existant or spent Mint.")

        if not claimers.contains(output.key):
            claimers.add(output.key)
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
    if send.inputs.len == 0:
        raise newException(ValueError, "Send has no inputs.")

    var
        #Sender.
        senders: seq[EdPublicKey] = newSeq[EdPublicKey](1)

        #Spent output loop variable.
        spent: SendOutput
        #Amount this transaction is processing.
        amount: uint64 = 0

    #Grab the first sender.
    try:
        senders[0] = transactions.loadUTXO(cast[SendInput](send.inputs[0])).key
    except DBreadError:
        raise newException(ValueError, "Send spends a non-existant or spent output.")

    #Add the amount the inputs provide.
    for input in send.inputs:
        try:
            spent = transactions.loadUTXO(cast[SendInput](input))
        except DBreadError:
            raise newException(ValueError, "Send spends a non-existant or spent output.")

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
    #Verify it wasn't already added.
    try:
        discard transactions[data.hash]
        raise newException(DataExists, "Data was already added.")
    except IndexError:
        discard

    #Verify the inputs length.
    if data.inputs.len == 0:
        raise newException(ValueError, "Data has no inputs.")

    #Load the sender (which also verifies the input exists, if it's not the sender's key).
    var sender: EdPublicKey
    try:
        sender = transactions.getSender(data)
    except DataMissing as e:
        raise newException(ValueError, e.msg)

    #Verify the signature.
    if not sender.verify(data.hash.toString(), data.signature):
        raise newException(ValueError, "Data has an invalid Signature.")

    #Add the Data.
    transactions.add(cast[Transaction](data))

#Save a Transaction. Do not apply any other checks.
proc save*(
    transactions: var Transactions,
    tx: Transaction
) {.inline, forceCheck: [].} =
    transactions.save(tx)

#Mint Meros to the specified key.
proc mint*(
    transactions: var Transactions,
    key: BLSPublicKey,
    amount: uint64
): Hash[384] {.forceCheck: [].} =
    #Create the Mint.
    var mint: Mint = newMint(
        transactions.mintNonce,
        key,
        amount
    )

    #Add it to Transactions.
    transactions.add(cast[Transaction](mint))

    #Increment the mint nonce.
    inc(transactions.mintNonce)

    #Return the mint hash.
    result = mint.hash

#Remove every hash in this Epoch from the cache/RAM, updating archived and the amount of Elements to reload.
proc archive*(
    transactions: var Transactions,
    consensus: Consensus,
    epoch: Epoch
) {.forceCheck: [].} =
    for record in epoch.records:
        #Remove every hash from this Epoch.
        #If we used the hashes in the Epoch, we'd only remove confirmed hashes.
        #We need to iterate over every Element archived in this Epoch and remove every mentioned hash.
        var
            #Previously popped height.
            prev: int
            #Elements.
            elems: seq[Element]
        try:
            prev = transactions.load(record.key)
        except DBReadError:
            prev = -1
        try:
            elems = consensus[record.key][prev + 1 .. record.nonce]
        except IndexError as e:
            doAssert(false, "Couldn't load Elements which were archived: " & e.msg)

        #Iterate over every archived Element,
        for elem in elems:
            transactions.del(cast[Verification](elem).hash.toString())

        #Save the popped height so we can reload Elements.
        transactions.save(record.key, record.nonce)
