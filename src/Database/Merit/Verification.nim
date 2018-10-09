#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet

#Verification object.
import objects/VerificationObj
export VerificationObj

#Finals lib.
import finals

#Create a new Verification.
proc newVerification*(
    hash: Hash[512]
): Verification {.raises: [].} =
    newVerificationObj(hash)

#Sign a TX.
func sign*(
    wallet: Wallet,
    verif: Verification
) {.raises: [SodiumError, FinalAttributeError].} =
    #Set the sender.
    verif.sender = wallet.address
    #Sign the hash of the Verification.
    verif.edSignature = wallet.sign(verif.hash.toString())
