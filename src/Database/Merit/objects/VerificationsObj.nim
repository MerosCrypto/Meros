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
            #Entry Hash.
            hash* {.final.}: Hash[512]

        #Verification object for the mempool.
        MemoryVerification* = ref object of Verification
            #BLS signature for aggregation in a block.
            signature* {.final.}: BLSSignature

        #A group of verifier/hash pairs with the final aggregate signature.
        Verifications* = ref object of RootObj
            #Verifications.
            verifications*: seq[MemoryVerification]
            #Aggregate signature.
            aggregate*: BLSSignature

#New Verification object.
func newVerificationObj*(
    hash: Hash[512]
): Verification {.raises: [].} =
    result = Verification(
        hash: hash
    )
    result.ffinalizeHash()

#New MemoryVerification object.
func newMemoryVerificationObj*(
    hash: Hash[512]
): MemoryVerification {.raises: [].} =
    result = MemoryVerification(
        hash: hash
    )
    result.ffinalizeHash()

#New Verifications object.
func newVerificationsObj*(): Verifications {.raises: [].} =
    Verifications(
        verifications: @[]
    )
