import ../../../lib/Errors

import ../../../Wallet/BLS

import ../../../lib/Hash

import finals

import ElementObj
export ElementObj

finalsd:
    type
        SendDifficulty* = ref object of Element
            difficulty* {.final.}: Hash[384]

        SignedSendDifficulty* = ref object of SendDifficulty
            signature* {.final.}: BLSSignature

func newSendDifficultyObj*(
    difficulty: Hash[384]
): SendDifficulty {.forceCheck: [].} =
    result = SendDifficulty(
        difficulty: difficulty
    )
    result.ffinalizeDifficulty()

func newSignedSendDifficultyObj*(
    difficulty: Hash[384]
): SignedSendDifficulty {.forceCheck: [].} =
    result = SignedSendDifficulty(
        difficulty: difficulty
    )
    result.ffinalizeDifficulty()
