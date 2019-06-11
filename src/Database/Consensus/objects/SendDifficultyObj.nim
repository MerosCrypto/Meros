import ../../../lib/Errors

import ../../../lib/Hash

import finals

import ElementObj

finalsd:
    type
        SendDifficulty* = ref object of Element
            difficulty* {.final.}: Hash[384]

        SignedSendDifficulty* = ref object of SendDifficulty
            signature* {.final.}: BLSSignature

func newSendDifficulty*(
    difficulty: Hash[384]
): SendDifficulty {.forceCheck: [].} =
    result = SendDifficulty(
        difficulty: difficulty
    )
    result.ffinalizeDifficulty()

func newSignedSendDifficulty*(
    difficulty: Hash[384]
): SignedSendDifficulty {.forceCheck: [].} =
    result = SignedSendDifficulty(
        difficulty: difficulty
    )
    result.ffinalizeDifficulty()
