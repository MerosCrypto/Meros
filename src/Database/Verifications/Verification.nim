#Verification object.
import objects/VerificationObj
export VerificationObj

#Finals lib.
import finals

#Mark a Verification as archived.
func archive*(verif: Verification, archived: uint): Verification =
    #We recreate the Verification in order to make sure it isn't a MemoryVerification.
    result = newVerificationObj(
        verif.hash
    )
    result.verifier = verif.verifier
    result.nonce = verif.nonce
    result.archived = archived

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
