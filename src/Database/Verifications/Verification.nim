#Verification object.
import objects/VerificationObj
export VerificationObj

#Finals lib.
import finals

#Mark a Verification as archived.
func archive*(verif: Verification, archived: uint) {.raises: [].} =
    #Recreate the Verification in order to make sure it isn't a MemoryVerification.
    var archive = newVerificationObj(
        verif.hash
    )
    archive.verifier = verif.verifier
    archive.nonce = verif.nonce
    archive.archived = archived

    #Set the input to the archive.
    verif = archive

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
