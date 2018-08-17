#Errors lib.
import ../../lib/Errors

#BN lib.
import ../../lib/BN

#SHA512 lib.
import ../../lib/SHA512

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
    input: string,
    output: string,
    amount: BN,
    nonce: BN
): Transaction {.raises: [ResultError, ValueError].} =
    #Verify input/output.
    if (not Wallet.verify(input)) or (not Wallet.verify(output)):
        raise newException(ValueError, "Transaction addresses are not valid.")

    #Verify the amount.
    if amount < BNNums.ZERO:
        raise newException(ValueError, "Transaction amount is negative.")

    #Craft the result.
    result = newTransactionObj(
        input,
        output,
        amount
    )

    #Set the descendant type.
    if not result.setDescendant(1):
        raise newException(ResultError, "Couldn't set the node's descendant type.")

    if not result.setNonce(nonce):
        raise newException(ResultError, "Setting the Transaction nonce failed.")

    #Set the hash.
    if not result.setHash(SHA512(result.serialize())):
        raise newException(ResultError, "Couldn't set the Transaction hash.")

#'Mine' a TX (beat the spam filter).
#IN PROGRESS.
proc mine*(toMine: Transaction, networkDifficulty: BN) {.raises: [].} =
    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    discard

#Sign a TX.
proc sign*(wallet: Wallet, tx: Transaction): bool {.raises: [ValueError].} =
    #Sign the hash of the TX.
    result = tx.setSignature(wallet.sign(tx.getHash()))
