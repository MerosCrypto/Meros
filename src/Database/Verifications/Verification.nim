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
proc sign*(
    miner: MinerWallet,
    verif: MemoryVerification,
    nonce: Natural
) {.raises: [BLSError, FinalAttributeError].} =
    #Set the verifier.
    verif.verifier = miner.publicKey
    #Set the nonce.
    verif.nonce = nonce
    #Sign the hash of the Verification.
    verif.signature = miner.sign(verif.hash.toString())
