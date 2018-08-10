#Errors lib.
import ../../lib/Errors

#Number libs.
import ../../lib/BN
import ../../lib/Base

#SHA512 lib.
import ../../lib/SHA512 as SHA512File
import ../../lib/Util

#Wallet libs.
import ../../Wallet/Wallet

#Node object.
import Node

#Used to handle data strings.
import strutils

#Transaction object.
type Transaction* = ref object of Node
    #Data used to create the hash.
    #Input address. This address for a send node, a different one for a receive node.
    input*: string
    #Output address. This address for a receive node, a different one for a send node.
    output*: string
    #Amount transacted.
    amount*: BN
    #Data included in the TX.
    data*: string

    #Data used to prove it isn't spam.
    #Difficulty units.
    diffUnits: BN
    #Proof this isn't spam.
    proof: BN
    #Argon2 hash.
    argon: string

#IN PROGRESS!
proc serialize*(tx: Transaction): string {.raises: [ValueError].} =
    result =
        tx.input.substr(3, tx.input.len).pad(64) &
        tx.output.substr(3, tx.output.len).pad(64)

    var amount: string = tx.amount.toString(16)
    if amount[0] == '0':
        amount = amount.substr(1, amount.len)
    result =
        amount.len.toHex() &
        amount &
        tx.data &
        tx.nonce.toString(16)

#Create a new  node.
proc newTransaction*(
    nonce: BN,
    blockNumber: BN,
    input: string,
    output: string,
    amount: BN,
    data: string
): Transaction {.raises: [ResultError, ValueError, Exception].} =
    #verify input/output.
    if (not Wallet.verify(input)) or (not Wallet.verify(output)):
        raise newException(ValueError, "Transaction addresses are not valid.")

    #Verify the amount.
    if amount < BNNums.ZERO:
        raise newException(ValueError, "Transaction amount is negative.")

    #Verify the data argument.
    if data.len > 127:
        raise newException(ValueError, "Transaction data was too long.")

    #Turn data into a hex string in order to hash it.
    var dataHex: string = ""
    for i in 0 ..< data.len:
        dataHex = dataHex & ord(data[i]).toHex()

    #Craft the result.
    result = Transaction(
        nonce: nonce,
        blockNumber: newBN(),

        input: input,
        output: output,
        amount: amount,
        data: data,
        diffUnits: newBN(1 + (2 * data.len))
    )

    if not result.setHash(
        (SHA512^2)(
            result.serialize()
        )
    ):
        raise newException(ResultError, "Setting the TX hash failed.")

#IN PROGRESS.
proc mine*(toMine: Transaction, networkDifficulty: BN) {.raises: [].} =
    toMine.diffUnits = newBN(1 + (toMine.data.len * 2))

    var difficulty: BN = toMine.diffUnits * networkDifficulty

#Sign a TX.
proc sign*(wallet: Wallet, toSign: Transaction): bool {.raises: [ValueError, Exception].} =
    #Set a default return value of true.
    result = true

    #Create a new node and make sure the newTransaction proc doesn't throw an error.
    var newTransaction: Transaction
    try:
        newTransaction = newTransaction(
            toSign.nonce,
            toSign.blockNumber,
            toSign.input,
            toSign.output,
            toSign.amount,
            toSign.data
        )
    except:
        result = false
        return

    if toSign.getHash() != newTransaction.getHash():
        result = false
        return

    if toSign.diffUnits != newBN(1 + (2 * toSign.data.len)):
        result = false
        return

    #Verify work and Argon2 hash.

    #Sign the Argon2 hash of the TX.
    toSign.setSignature(wallet.sign(toSign.argon))
