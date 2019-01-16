#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Verification object.
import objects/VerificationObj
export VerificationObj

#Finals lib.
import finals

#Sign a Verification.
func sign*(
    miner: MinerWallet,
    verif: MemoryVerification,
    nonce: uint
) {.raises: [FinalAttributeError].} =
    #Set the verifier.
    verif.verifier = miner.publicKey
    #Set the nonce.
    verif.nonce = nonce
    #Sign the hash of the Verification.
    verif.signature = miner.sign(verif.hash.toString())
