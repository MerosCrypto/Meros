#Errors lib.
import ../../../../lib/Errors

#MinerWallet lib.
import ../../../../Wallet/MinerWallet

#Element object.
import ElementObj
export ElementObj

#DataDifficulty objects.
type
    DataDifficulty* = ref object of BlockElement
        nonce*: int
        difficulty*: uint32

    SignedDataDifficulty* = ref object of DataDifficulty
        signature*: BLSSignature

#Constructors.
func newDataDifficultyObj*(
    nonce: int,
    difficulty: uint32
): DataDifficulty {.inline, forceCheck: [].} =
    DataDifficulty(
        nonce: nonce,
        difficulty: difficulty
    )

func newSignedDataDifficultyObj*(
    nonce: int,
    difficulty: uint32
): SignedDataDifficulty {.inline, forceCheck: [].} =
    SignedDataDifficulty(
        nonce: nonce,
        difficulty: difficulty
    )
