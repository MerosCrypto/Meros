#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element object.
import ElementObj
export ElementObj

#Finals lib.
import finals

#Verification objects.
finalsd:
    type
        Verification* = ref object of Element
            hash* {.final.}: Hash[384]

        SignedVerification* = ref object of Verification
            signature* {.final.}: BLSSignature

#Constructors.
func newVerificationObj*(
    hash: Hash[384]
): Verification {.forceCheck: [].} =
    result = Verification(
        hash: hash
    )
    result.ffinalizeHash()

func newSignedVerificationObj*(
    hash: Hash[384]
): SignedVerification {.forceCheck: [].} =
    result = SignedVerification(
        hash: hash
    )
    result.ffinalizeHash()
