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
    #Data used to create the SHA512 hash.
    #Input address. This address for a send node, a different one for a receive node.
    input: string
    #Output address. This address for a receive node, a different one for a send node.
    output: string
    #Amount transacted.
    amount: BN
    #Data included in the TX.
    data: seq[uint8]

    #SHA512 hash.
    sha512: string

    #Data used to prove it isn't spam.
    #Difficulty units.
    diffUnits: BN
    #Proof this isn't spam.
    proof: BN

#Generate a hash for a TX.
proc hash*(tx: Transaction) {.raises: [ResultError, ValueError, Exception].} =
    var
        delim: string = $((char) 0)
        hash: string

    hash =
        tx.getNonce().toString(255) & delim &
        tx.input.substr(3, tx.input.len).toBN(58).toString(255) & delim &
        tx.output.substr(3, tx.output.len).toBN(58).toString(255) & delim &
        tx.amount.toString(255) & delim

    for i in tx.data:
        hash = hash & $((char) i)

    hash = (SHA512^2)(hash)

    if not tx.setHash(hash):
        raise newException(ResultError, "Setting the TX hash failed.")

#Serialize a TX for broadcasting over a network.
proc serialize*(tx: Transaction): string {.raises: [ValueError].} =
    var delim: string = $((char) 0)

    result =
        tx.getNonce().toString(255) & delim &
        tx.input.substr(3, tx.input.len).toBN(58).toString(255) & delim &
        tx.output.substr(3, tx.output.len).toBN(58).toString(255) & delim &
        tx.amount.toString(255) & delim

    for i in tx.data:
        result = result & $((char) i)

    result =
        result & delim &
        tx.proof.toString(255) & delim &
        tx.getSignature().toBN(16).toString(255)

#Create a new  node.
proc newTransaction*(
    nonce: BN,
    input: string,
    output: string,
    amount: BN,
    data: seq[uint8]
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
    for i in data:
        dataHex = dataHex & $i.toHex()

    #Craft the result.
    result = Transaction(
        input: input,
        output: output,
        amount: amount,
        data: data,

        diffUnits: newBN(1 + (2 * data.len))
    )

    if not result.setNonce(nonce):
        raise newException(ResultError, "Setting the TX nonce failed.")

    result.hash()

#'Mine' a TX (beat the spam filter).
#IN PROGRESS.
proc mine*(toMine: Transaction, networkDifficulty: BN) {.raises: [ValueError].} =
    if toMine.diffUnits.isNil:
        raise newException(ValueError, "Transaction didn't have its difficulty units set..")

    #Check the networkDifficulty value.

    var difficulty: BN = toMine.diffUnits * networkDifficulty

    #Generate proofs until the SHA512 cubed hash beats the difficulty.

#Sign a TX.
proc sign*(wallet: Wallet, tx: Transaction): bool {.raises: [ValueError].} =
    #Sign the hash of the TX.
    result = tx.setSignature(wallet.sign(tx.getHash()))
