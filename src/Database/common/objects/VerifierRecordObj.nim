#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Verifications Index object.
import VerificationsIndexObj
export VerificationsIndexObj

#Finals lib.
import finals

finalsd:
    #VerifierRecord object. Specifies a verifier, tip, and merkle of all entries to that point.
    type VerifierRecord* = object of VerificationsIndex
        merkle* {.final.}: Hash[384]

#Constructor.
func newVerifierRecord*(
    key: BLSPublicKey,
    nonce: Natural,
    merkle: Hash[384]
): VerifierRecord {.forceCheck: [].} =
    result = VerifierRecord(
        merkle: merkle
    )
    result.ffinalizeMerkle()

    try:
        result.key = key
        result.nonce = nonce
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a VerifierRecord: " & e.msg)
