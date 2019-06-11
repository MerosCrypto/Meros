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

#Difficulties object.
import objects/DifficultiesObj

#Transaction object, along with the Mint, Claim, and Send libraries.
import objects/TransactionObj
import Mint
import Claim
import Send

#Transactions object.
import objects/TransactionsObj

#Seq utils standard lib.
import sequtils

#Tables standard lib.
import tables

#Add a Verification to the weights table.
proc verify*(
    transactions: var Transactions,
    verif: Verification,
    merit: int,
    liveMerit: int,
    save: bool
) {.forceCheck: [
    ValueError
].} =
    #Turn the hash into a string.
    var hash: string = verif.hash.toString()

    #Verify the Transaction exists.
    if not transactions.transactions.hasKey(hash):
        raise newException(ValueError, "Transaction either doesn't exist or is already out of the Epochs.")

    #Add the Verification.
    var weight: int
    try:
        transactions.weights[hash] += merit
        #Save the weight so we can use it in the future without a potential KeyError.
        weight = transactions.weights[hash]
    except KeyError as e:
        doAssert(false, "Couldn't get a Transaction's weight despite guaranteeing it had a weight: " & e.msg)

    #If the Transaction has at least 50.1% of the weight (+ 600 for the Meros minted while a Transaction can be verified)...
    if weight > (liveMerit div 2) + 601:
        #Grab the Transaction.
        var tx: Transaction
        try:
            tx = transactions.transactions[hash]
        except KeyError:
            raise newException(ValueError, "Couldn't get a Transaction despite confirming it's in the cache.")

        #If the Transaction was already verified, return.
        if tx.verified:
            return

        #Guarantee all spent UTXOs are still available.
        for input in tx.inputs:
            case tx.descendant:
                of TransactionType.Claim:
                    try:
                        discard transactions.mints[input.hash.toString()]
                    except KeyError:
                        doAssert(false, "Verified Claim spends no longer spendable Mints.")

                of TransactionType.Send:
                    try:
                        discard transactions.sends[input.hash.toString() & char(cast[SendInput](input).nonce)]
                    except KeyError:
                        doAssert(false, "Verified Send spends no longer spendable UTXOs.")

                else:
                    discard

        #Set it to verified.
        tx.verified = true

        #If we're not just reloading Verifications, and should update UTXOs...
        if save:
            echo verif.hash, " was verified."

            #Mark spent UTXOs as spent and create new UTXOs.
            case tx.descendant:
                of TransactionType.Claim:
                    #Up to 255 Mint UTXOs spent.
                    for input in tx.inputs:
                        transactions.mints.del(input.hash.toString())
                    #One output created.
                    transactions.sends[hash] = cast[SendOutput](tx.outputs[0])

                of TransactionType.Send:
                    #Up to 255 Send UTXOs spent.
                    for input in tx.inputs:
                        transactions.sends.del(input.hash.toString() & char(cast[SendInput](input).nonce))
                    #Up to 255 Send UTXOs created.
                    for i in 0 ..< tx.outputs.len:
                        transactions.sends[hash & char(i)] = cast[SendOutput](tx.outputs[i])

                else:
                    discard

#Constructor.
proc newTransactions*(
    db: DB,
    sendDiff: string,
    dataDiff: string
): Transactions {.forceCheck: [].} =
    #Create the Transactions.
    newTransactionsObj(
        db,
        sendDiff,
        dataDiff
    )

#Add a Mint.
proc add*(
    transactions: var Transactions,
    mint: Mint
) {.forceCheck: [].} =
    transactions.add(cast[Transaction](mint))
    transactions.mints[mint.hash.toString()] = cast[MintOutput](mint.outputs[0])

#Add a Claim.
proc add*(
    transactions: var Transactions,
    claim: Claim
) {.forceCheck: [
    ValueError
].} =
    var
        #Claimer.
        claimer: BLSPublicKey

        #Output loop variable.
        output: MintOutput
        #Amount this Claim is claiming.
        amount: uint64 = 0

    #Grab the Claimer.
    try:
         claimer = transactions.mints[claim.inputs[0].hash.toString()].key
    except KeyError:
        raise newException(ValueError, "Claim spends a non-existant or spent Mint.")

    #Add the amount the inputs provide.
    for input in claim.inputs:
        try:
            output = transactions.mints[input.hash.toString()]
        except KeyError:
            raise newException(ValueError, "Claim spends a non-existant or spent Mint.")

        if output.key != claimer:
            raise newException(ValueError, "Claim inputs have different keys.")

        amount += output.amount

    #Set the Claim's output amount to the amount.
    try:
        claim.outputs[0].amount = amount
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when adding a Claim: " & e.msg)

    #Verify the signature.
    if not claim.verify(claimer):
        raise newException(ValueError, "Claim has an invalid Signature.")

    #Add the Claim.
    transactions.add(cast[Transaction](claim))

#Add a Send.
proc add*(
    transactions: var Transactions,
    send: Send
) {.forceCheck: [
    ValueError
].} =
    #Verify the Send's proof.
    if send.argon < transactions.difficulties.send:
        raise newException(ValueError, "Send has an invalid proof.")

    var
        #Sender.
        sender: EdPublicKey

        #Output loop variable.
        output: SendOutput
        #Amount this transaction is processing.
        amount: uint64 = 0

    #Grab the Sender.
    try:
        sender = transactions.sends[send.inputs[0].hash.toString() & char(cast[SendInput](send.inputs[0]).nonce)].key
    except KeyError:
        raise newException(ValueError, "Send spends a non-existant or spent output.")

    #Add the amount the inputs provide.
    for input in send.inputs:
        try:
            output = transactions.sends[input.hash.toString() & char(cast[SendInput](input).nonce)]
        except KeyError:
            raise newException(ValueError, "Send spends a non-existant or spent output.")

        if output.key != sender:
            raise newException(ValueError, "Send inputs have different keys.")

        amount += output.amount

    #Subtract the amount the outpts spend.
    for ouput in send.outputs:
        amount -= output.amount

    #If the amount is not 9, there's a problem
    #It should be noted, amount can underflow. It's impossible to spend the full underflow.
    if amount != 0:
        raise newException(ValueError, "Send outputs don't spend the amount provided by the inputs.")

    #Verify the signature.
    if not sender.verify(send.hash.toString(), send.signature):
        raise newException(ValueError, "Send has an invalid Signature.")

    #Add the Send.
    transactions.add(cast[Transaction](send))

#Mint Meros to the specified key.
proc mint*(
    transactions: var Transactions,
    key: BLSPublicKey,
    amount: uint64
) {.forceCheck: [].} =
    #Create the Mint transaction and add it to the Transactions.
    transactions.add(
        newMint(
            transactions.mintNonce,
            key,
            amount
        )
    )

    #Increment the mint nonce.
    inc(transactions.mintNonce)
