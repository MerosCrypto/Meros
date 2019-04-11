#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Finals lib.
import finals

finalsd:
    type
        #Verification object.
        Verification* = ref object of RootObj
            #BLS Key.
            verifier* {.final.}: BLSPublicKey
            #Nonce.
            nonce* {.final.}: Natural
            #Entry Hash.
            hash* {.final.}: Hash[384]

        #Verification object for the mempool.
        MemoryVerification* = ref object of Verification
            #BLS signature for aggregation in a block.
            signature* {.final.}: BLSSignature

#New Verification object.
func newVerificationObj*(
    hash: Hash[384]
): Verification {.forceCheck: [].} =
    result = Verification(
        hash: hash
    )
    result.ffinalizeHash()

#New MemoryVerification object.
func newMemoryVerificationObj*(
    hash: Hash[384]
): MemoryVerification {.forceCheck: [].} =
    result = MemoryVerification(
        hash: hash
    )
    result.ffinalizeHash()
