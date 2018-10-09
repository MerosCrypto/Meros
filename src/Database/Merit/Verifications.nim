#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet

#Verification object.
import objects/VerificationsObj
export VerificationsObj

#Finals lib.
import finals

#Create a new Verification.
proc newMemoryVerification*(
    hash: Hash[512]
): MemoryVerification {.raises: [].} =
    newMemoryVerificationObj(hash)

#Sign a TX.
func sign*(
    wallet: Wallet,
    verif: MemoryVerification
) {.raises: [SodiumError, FinalAttributeError].} =
    #Set the sender.
    verif.sender = wallet.address
    #Sign the hash of the Verification.
    verif.edSignature = wallet.sign(verif.hash.toString())
