#Errors lib.
import ../../../../lib/Errors

#Hash lib/
import ../../../../lib/Hash

#MinerWallet lib.
import ../../../../Wallet/MinerWallet

#Element object.
import ElementObj
export ElementObj

#SendDifficulty objects.
type
    SendDifficulty* = ref object of BlockElement
        difficulty*: Hash[384]

    SignedSendDifficulty* = ref object of SendDifficulty
        signature*: BLSSignature

#Constructors/
func newSendDifficultyObj*(
    difficulty: Hash[384]
): SendDifficulty {.inline, forceCheck: [].} =
    SendDifficulty(
        difficulty: difficulty
    )

func newSignedSendDifficultyObj*(
    difficulty: Hash[384]
): SignedSendDifficulty {.inline, forceCheck: [].} =
    SignedSendDifficulty(
        difficulty: difficulty
    )
