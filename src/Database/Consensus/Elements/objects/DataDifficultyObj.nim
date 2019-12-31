#Errors lib.
import ../../../../lib/Errors

#Hash lib/
import ../../../../lib/Hash

#MinerWallet lib.
import ../../../../Wallet/MinerWallet

#Element object.
import ElementObj
export ElementObj

#Finals lib.
import finals

#DataDifficulty objects.
finalsd:
    type
        DataDifficulty* = ref object of BlockElement
            nonce* {.final.}: int
            difficulty* {.final.}: Hash[384]

        SignedDataDifficulty* = ref object of DataDifficulty
            signature* {.final.}: BLSSignature

#Constructors.
func newDataDifficultyObj*(
    nonce: int,
    difficulty: Hash[384]
): DataDifficulty {.forceCheck: [].} =
    result = DataDifficulty(
        nonce: nonce,
        difficulty: difficulty
    )
    result.ffinalizeDifficulty()

func newSignedDataDifficultyObj*(
    nonce: int,
    difficulty: Hash[384]
): SignedDataDifficulty {.forceCheck: [].} =
    result = SignedDataDifficulty(
        nonce: nonce,
        difficulty: difficulty
    )
    result.ffinalizeDifficulty()
