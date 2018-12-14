#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Finals lib.
import finals

#String utils standard lib.
import strutils

finalsd:
    type
        #Verification object.
        Verification* = ref object of RootObj
            #BLS Key.
            verifier* {.final.}: BLSPublicKey
            #Nonce.
            nonce* {.final.}: uint
            #Entry Hash.
            hash* {.final.}: Hash[512]
            #Block the Verification was archived in.
            archived: uint

        #Verification object for the mempool.
        MemoryVerification* = ref object of Verification
            #BLS signature for aggregation in a block.
            signature* {.final.}: BLSSignature

#New Verification object.
func newVerificationObj*(
    hash: Hash[512]
): Verification {.raises: [].} =
    result = Verification(
        hash: hash,
        archived: 0
    )
    result.ffinalizeHash()

#New MemoryVerification object.
func newMemoryVerificationObj*(
    hash: Hash[512]
): MemoryVerification {.raises: [].} =
    result = MemoryVerification(
        hash: hash,
        archived: 0
    )
    result.ffinalizeHash()

#Mark a Verification as archived.
func archive*(verif: Verification, archived: uint): Verification =
    #We recreate the Verification in order to make sure it isn't a MemoryVerification.
    result = Verification(
        verifier: verif.verifier,
        hash: verif.hash,
        archived: archived
    )
    result.ffinalizeVerifier()
    result.ffinalizeHash()
    result.ffinalizeArchived()


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
