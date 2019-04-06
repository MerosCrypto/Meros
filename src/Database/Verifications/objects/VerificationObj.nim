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
            hash* {.final.}: Hash[384]

        #Verification object for the mempool.
        MemoryVerification* = ref object of Verification
            #BLS signature for aggregation in a block.
            signature* {.final.}: BLSSignature

#New Verification object.
func newVerificationObj*(
    hash: Hash[384]
): Verification {.raises: [].} =
    result = Verification(
        hash: hash
    )
    result.ffinalizeHash()

#New MemoryVerification object.
func newMemoryVerificationObj*(
    hash: Hash[384]
): MemoryVerification {.raises: [].} =
    result = MemoryVerification(
        hash: hash
    )
    result.ffinalizeHash()
