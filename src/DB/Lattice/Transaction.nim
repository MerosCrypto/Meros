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

#Import the Serialization library.
import ../../Network/Serialize

#Node object.
import objects/NodeObj

#Transaction object.
import objects/TransactionObj
export TransactionObj

#Used to handle data strings.
import strutils

#Create a new  node.
proc newTransaction*(
    nonce: BN,
    input: string,
    output: string,
    amount: BN,
    data: seq[uint8]
): Transaction {.raises: [ResultError, ValueError].} =
    #Verify input/output.
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
    result = newTransactionObj(
        input,
        output,
        amount,
        data
    )

    #Set the descendant type.
    if not result.setDescendant(1):
        raise newException(ResultError, "Couldn't set the node's descendant type.")

    if not result.setNonce(nonce):
        raise newException(ResultError, "Setting the TX nonce failed.")

    #Set the hash.
    if not result.setHash(SHA512(result.serialize())):
        raise newException(ResultError, "Couldn't set the TX hash.")

#'Mine' a TX (beat the spam filter).
#IN PROGRESS.
proc mine*(toMine: Transaction, networkDifficulty: BN) {.raises: [ValueError].} =
    if toMine.getDiffUnits().isNil:
        raise newException(ValueError, "Transaction didn't have its difficulty units set..")

    #Check the networkDifficulty value.

    var difficulty: BN = toMine.getDiffUnits() * networkDifficulty

    #Generate proofs until the SHA512 cubed hash beats the difficulty.

#Sign a TX.
proc sign*(wallet: Wallet, tx: Transaction): bool {.raises: [ValueError].} =
    #Sign the hash of the TX.
    result = tx.setSignature(wallet.sign(tx.getHash()))
