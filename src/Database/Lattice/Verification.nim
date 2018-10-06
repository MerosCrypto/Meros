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

#Finals lib.
import finals

#Create a new Verification.
proc newVerification*(
    node: Node,
    nonce: BN
): Verification {.raises: [ValueError, FinalAttributeError].} =
    result = newVerificationObj(
        node.hash
    )
    #Set the nonce.
    result.nonce = nonce
    #Set the hash.
    result.hash = SHA512(result.serialize())

#Sign a TX.
func sign*(
    wallet: Wallet,
    verif: Verification
) {.raises: [SodiumError, FinalAttributeError].} =
    #Set the sender behind the node.
    verif.sender = wallet.address
    #Sign the hash of the Verification.
    verif.signature = wallet.sign(verif.hash.toString())
