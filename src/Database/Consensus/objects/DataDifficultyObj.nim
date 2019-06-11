import ../../../lib/Errors

import ../../../lib/Hash

import finals

import ElementObj

finalsd:
    type
        DataDifficulty* = ref object of Element
            difficulty* {.final.}: Hash[384]

        SignedDataDifficulty* = ref object of DataDifficulty
            signature* {.final.}: BLSSignature

func newDataDifficulty*(
    difficulty: Hash[384]
): DataDifficulty {.forceCheck: [].} =
    result = DataDifficulty(
        difficulty: difficulty
    )
    result.ffinalizeDifficulty()

func newSignedDataDifficulty*(
    difficulty: Hash[384]
): SignedDataDifficulty {.forceCheck: [].} =
    result = SignedDataDifficulty(
        difficulty: difficulty
    )
    result.ffinalizeDifficulty()
