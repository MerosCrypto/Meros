#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Finals lib.
import finals

finalsd:
    #ConsensusIndex object. Specifies a position on the Consensus DAG.
    type ConsensusIndex* = object of RootObj
        key* {.final.}: BLSPublicKey
        nonce* {.final.}: int

#Constructor.
func newConsensusIndex*(
    key: BLSPublicKey,
    nonce: Natural
): ConsensusIndex {.forceCheck: [].} =
    result = ConsensusIndex(
        key: key,
        nonce: nonce
    )
    result.ffinalizeKey()
    result.ffinalizeNonce()
