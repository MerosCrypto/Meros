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
export toString, getUTXOs, loadSpenders, verify, unverify, prune

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
        raise newLoggedException(DataExists, "Claim was already added.")
    except IndexError:
        discard

    var
        #Claimers.
        claimers: seq[BLSPublicKey] = newSeq[BLSPublicKey]()

        #Table of spent inputs.
        inputTable: HashSet[string] = initHashSet[string]()
        #Output loop variable.
        output: MintOutput
        #Key loop variable.
        key: BLSPublicKey
        #Amount this Claim is claiming.
        amount: uint64 = 0

    #Add the amount the inputs provide. Also verify no inputs are spent multiple times.
    for input in claim.inputs:
        if inputTable.contains(input.toString()):
            raise newLoggedException(ValueError, "Claim spends the same input twice.")
        inputTable.incl(input.toString())

        try:
            if not (transactions[input.hash] of Mint):
                raise newLoggedException(ValueError, "Claim doesn't spend a Mint.")
        except IndexError:
            raise newLoggedException(ValueError, "Claim spends a non-existant Mint.")

        try:
            output = transactions.loadMintOutput(cast[FundedInput](input))
        except DBReadError:
            raise newLoggedException(ValueError, "Claim spends a non-existant Mint.")

        try:
            key = lookup(output.key)
        except IndexError as e:
            panic("Created a Mint to a non-existent Merit Holder: " & e.msg)

        claimers.add(key)
        amount += output.amount

    #Set the Claim's output amount to the amount.
    claim.outputs[0].amount = amount

    #Verify the signature.
    if not claim.verify(claimers):
        raise newLoggedException(ValueError, "Claim has an invalid Signature.")

    #Add the Claim.
    try:
        transactions.add(cast[Transaction](claim))
    except ValueError as e:
        raise e

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
        raise newLoggedException(DataExists, "Send was already added.")
    except IndexError:
        discard

    #Verify the inputs length.
    if send.inputs.len < 1 or 255 < send.inputs.len:
        raise newLoggedException(ValueError, "Send has too little or too many inputs.")
    #Verify the outputs length.
    if send.outputs.len < 1 or 255 < send.outputs.len:
        raise newLoggedException(ValueError, "Send has too little or too many outputs.")

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
        senders[0] = transactions.loadSendOutput(cast[FundedInput](send.inputs[0])).key
    except DBReadError:
        raise newLoggedException(ValueError, "Send spends a non-existant output.")

    #Add the amount the inputs provide. Also verify no inputs are spent multiple times.
    for input in send.inputs:
        if inputTable.contains(input.toString()):
            raise newLoggedException(ValueError, "Send spends the same input twice.")
        inputTable.incl(input.toString())

        try:
            if (
                (not (transactions[input.hash] of Claim)) and
                (not (transactions[input.hash] of Send))
            ):
                raise newLoggedException(ValueError, "Send doesn't spend a Claim or Send.")
        except IndexError:
            raise newLoggedException(ValueError, "Send spends a non-existant Claim or Send.")

        try:
            spent = transactions.loadSendOutput(cast[FundedInput](input))
        except DBReadError:
            raise newLoggedException(ValueError, "Send spends a non-existant output.")

        if not senders.contains(spent.key):
            senders.add(spent.key)

        amount += spent.amount

    #Subtract the amount the outpts spend.
    for output in send.outputs:
        if output.amount == 0:
            raise newLoggedException(ValueError, "Send output has an amount of 0.")

        amount -= output.amount

    #If the amount is not 9, there's a problem
    #It should be noted, amount can underflow. It's impossible to spend the full underflow.
    if amount != 0:
        raise newLoggedException(ValueError, "Send outputs don't spend the amount provided by the inputs.")

    #Verify the signature.
    if not senders.aggregate().verify(send.hash.toString(), send.signature):
        raise newLoggedException(ValueError, "Send has an invalid Signature.")

    #Add the Send.
    try:
        transactions.add(cast[Transaction](send))
    except ValueError as e:
        raise e

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
        raise newLoggedException(DataExists, "Data was already added.")
    except IndexError:
        discard

    #Verify the inputs length.
    if data.inputs.len != 1:
        raise newLoggedException(ValueError, "Data doesn't have one input.")

    #Load the sender (which also verifies the input exists, if it's not the sender's key).
    var sender: EdPublicKey
    try:
        sender = transactions.getSender(data)
    except DataMissing as e:
        raise newLoggedException(ValueError, "Data's input is either missing or not a Data: " & e.msg)

    #Verify the signature.
    if not sender.verify(data.hash.toString(), data.signature):
        raise newLoggedException(ValueError, "Data has an invalid Signature.")

    #Add the Data.
    try:
        transactions.add(cast[Transaction](data))
    except ValueError as e:
        raise e

#Mint Meros to the specified key.
proc mint*(
    transactions: var Transactions,
    hash: Hash[256],
    rewards: seq[Reward]
) {.forceCheck: [].} =
    #Create the outputs.
    #The used Meri quantity is the score * 50.
    #Once we add a proper rewards curve, this will change.
    #This is just a value which works for testing.
    var outputs: seq[MintOutput] = newSeq[MintOutput](rewards.len)
    for r in 0 ..< rewards.len:
        outputs[r] = newMintOutput(rewards[r].nick, rewards[r].score * 50)

    #Create the Mint.
    var mint: Mint = newMint(hash, outputs)

    #Add it to Transactions.
    try:
        transactions.add(cast[Transaction](mint))
    except ValueError as e:
        panic("Adding a Mint raised a ValueError: " & e.msg)

    #Verify it.
    transactions.verify(mint.hash)

#Remove every hash in this Epoch from the cache/RAM.
proc archive*(
    transactions: var Transactions,
    epoch: Epoch
) {.forceCheck: [].} =
    for hash in epoch.keys():
        transactions.del(hash)
