#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#ConsensusIndex object.
import ConsensusIndexObj
export ConsensusIndexObj

#Finals lib.
import finals

finalsd:
    #MeritHolderRecord object. Specifies a holder, tip, and merkle of all entries to that point.
    type MeritHolderRecord* = object of ConsensusIndex
        merkle* {.final.}: Hash[384]

#Constructor.
func newMeritHolderRecord*(
    key: BLSPublicKey,
    nonce: Natural,
    merkle: Hash[384]
): MeritHolderRecord {.forceCheck: [].} =
    result = MeritHolderRecord(
        merkle: merkle
    )
    result.ffinalizeMerkle()

    try:
        result.key = key
        result.nonce = nonce
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a MeritHolderRecord: " & e.msg)
