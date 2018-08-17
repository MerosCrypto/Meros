#Errors lib.
import ../../lib/Errors

#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#Hashing libs.
import ../../lib/SHA512
import ../../lib/Argon

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

    #Set the nonce.
    if not result.setNonce(nonce):
        raise newException(ResultError, "Setting the Transaction nonce failed.")

    #Set the hash.
    if not result.setSHA512(SHA512(result.serialize())):
        raise newException(ResultError, "Couldn't set the Transaction SHA512.")

#'Mine' a TX (beat the spam filter).
proc mine*(tx: Transaction, networkDifficulty: BN) {.raises: [ResultError, ValueError].} =
    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    var
        proof: BN = newBN()
        hash: string = "00"

    while hash.toBN(16) < networkDifficulty:
        hash = Argon(tx.getSHA512(), proof.toString(16), true)

    if tx.setProof(proof) == false:
        raise newException(ResultError, "Couldn't set the Transaction proof.")
    if tx.setHash(hash) == false:
        raise newException(ResultError, "Couldn't set the Transaction hash.")

#Sign a TX.
proc sign*(wallet: Wallet, tx: Transaction): bool {.raises: [ValueError].} =
    if tx.getProof().isNil:
        result = false
        return

    #Sign the hash of the TX.
    result = tx.setSignature(wallet.sign(tx.getHash()))
