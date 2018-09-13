#Errors lib.
import ../../lib/Errors

#BN lib.
import BN

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize/SerializeVerification

#Node object and Send lib.
import objects/NodeObj
import Send

#Send object.
import objects/VerificationObj
export VerificationObj

#SetOnce lib.
import SetOnce

proc newVerification*(node: Node, nonce: BN): Verification {.raises: [ValueError, Exception].} =
    result = newVerificationObj(
        node.hash
    )
    #Set the nonce.
    result.nonce.value = nonce
    #Set the hash.
    result.hash.value = SHA512(result.serialize())

#Sign a TX.
proc sign*(wallet: Wallet, verif: Verification) {.raises: [ValueError].} =
    #Set the sender behind the node.
    verif.sender.value = wallet.address
    #Sign the hash of the Verification.
    verif.signature.value = wallet.sign($verif.hash.toValue())
