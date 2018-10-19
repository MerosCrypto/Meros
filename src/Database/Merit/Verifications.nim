#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import Miner/MinerWallet

#Verification object.
import objects/VerificationsObj
export VerificationsObj

#Finals lib.
import finals

#BLS lib.
import BLS

#Create a new Verification.
func newMemoryVerification*(
    hash: Hash[512]
): MemoryVerification {.raises: [].} =
    newMemoryVerificationObj(hash)

#Sign a Verification.
func sign*(
    miner: MinerWallet,
    verif: MemoryVerification
) {.raises: [FinalAttributeError].} =
    #Set the verifier.
    verif.verifier = miner.publicKey
    #Sign the hash of the Verification.
    verif.signature = miner.sign(verif.hash.toString())
