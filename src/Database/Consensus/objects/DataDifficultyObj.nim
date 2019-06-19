#Errors lib.
import ../../../lib/Errors

#Hash lib/
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element object.
import ElementObj
export ElementObj

#Finals lib.
import finals

#DataDifficulty objects.
finalsd:
    type
        DataDifficulty* = ref object of Element
            difficulty* {.final.}: Hash[384]

        SignedDataDifficulty* = ref object of DataDifficulty
            signature* {.final.}: BLSSignature

#Constructors.
func newDataDifficultyObj*(
    difficulty: Hash[384]
): DataDifficulty {.forceCheck: [].} =
    result = DataDifficulty(
        difficulty: difficulty
    )
    result.ffinalizeDifficulty()

func newSignedDataDifficultyObj*(
    difficulty: Hash[384]
): SignedDataDifficulty {.forceCheck: [].} =
    result = SignedDataDifficulty(
        difficulty: difficulty
    )
    result.ffinalizeDifficulty()
