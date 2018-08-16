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

#Node object and Transaction lib.
import objects/NodeObj
import Transaction

#Transaction object.
import objects/VerificationObj
export VerificationObj

proc newVerification*(tx: Transaction, nonce: BN): Verification {.raises: [ResultError].} =
    result = newVerificationObj(
        tx.getInput(),
        tx.getNonce(),
        tx.getHash()
    )

    #Set the descendant type.
    if not result.setDescendant(2):
        raise newException(ResultError, "Couldn't set the node's descendant type.")

    if not result.setNonce(nonce):
        raise newException(ResultError, "Setting the Verification nonce failed.")

    #Set the hash.
    if not result.setHash(SHA512(result.serialize())):
        raise newException(ResultError, "Couldn't set the Verification hash.")

#Sign a TX.
proc sign*(wallet: Wallet, verif: Verification): bool {.raises: [ValueError].} =
    #Sign the hash of the TX.
    result = verif.setSignature(wallet.sign(verif.getHash()))
