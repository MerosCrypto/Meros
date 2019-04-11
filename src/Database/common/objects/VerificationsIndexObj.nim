#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Finals lib.
import finals

finalsd:
    #VerificationsIndex object. Specifies a position on the Verifications DAG.
    type VerificationsIndex* = object of RootObj
        key* {.final.}: BLSPublicKey
        nonce* {.final.}: int

#Constructor.
func newVerificationsIndex*(
    key: BLSPublicKey,
    nonce: Natural
): VerificationsIndex {.forceCheck: [].} =
    result = VerificationsIndex(
        key: key,
        nonce: nonce
    )
    result.ffinalizeKey()
    result.ffinalizeNonce()
