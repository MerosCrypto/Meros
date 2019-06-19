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

#SendDifficulty objects.
finalsd:
    type
        SendDifficulty* = ref object of Element
            difficulty* {.final.}: Hash[384]

        SignedSendDifficulty* = ref object of SendDifficulty
            signature* {.final.}: BLSSignature

#Constructors/
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
