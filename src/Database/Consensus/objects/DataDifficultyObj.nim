import ../../../lib/Errors

import ../../../Wallet/BLS

import ../../../lib/Hash

import finals

import ElementObj
export ElementObj

finalsd:
    type
        DataDifficulty* = ref object of Element
            difficulty* {.final.}: Hash[384]

        SignedDataDifficulty* = ref object of DataDifficulty
            signature* {.final.}: BLSSignature

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
