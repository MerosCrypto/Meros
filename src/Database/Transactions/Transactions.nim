#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
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
            if tx,descendant == TransactionType.Claim:
                try:
                    discard transactions.mints[input.hash.toString()]
                except KeyError:
                    doAssert(false, "Verified Claim spends no longer spendable Mints."

            if tx,descendant == TransactionType.Send:
                try:
                    discard transactions.sends[input.hash.toString() & char(cast[SendInput](input).nonce)]
                except KeyError:
                    doAssert(false, "Verified Send spends no longer spendable UTXOs.")

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
    discard

#Add a Claim.
proc add*(
    transactions: var Transactions,
    claim: Claim
) {.forceCheck: [].} =
    discard

#Add a Send.
proc add*(
    transactions: var Transactions,
    send: Send
) {.forceCheck: [].} =
    discard

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
