#Errors lib.
import ../../../../lib/Errors

#Hash lib.
import ../../../../lib/Hash

#MinerWallet lib.
import ../../../../Wallet/MinerWallet

#Element object.
import ElementObj
export ElementObj

#Verification objects.
type
    Verification* = ref object of Element
        holder*: uint16
        hash*: Hash[384]

    SignedVerification* = ref object of Verification
        signature*: BLSSignature

#Constructors.
func newVerificationObj*(
    hash: Hash[384]
): Verification {.inline, forceCheck: [].} =
    Verification(
        hash: hash
    )

func newSignedVerificationObj*(
    hash: Hash[384]
): SignedVerification {.inline, forceCheck: [].} =
    SignedVerification(
        hash: hash
    )
