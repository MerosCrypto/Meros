#Errors lib.
import ../../../../lib/Errors

#MinerWallet lib.
import ../../../../Wallet/MinerWallet

#Element object.
import ElementObj
export ElementObj

#SendDifficulty objects.
type
  SendDifficulty* = ref object of BlockElement
    nonce*: int
    difficulty*: uint32

  SignedSendDifficulty* = ref object of SendDifficulty
    signature*: BLSSignature

#Constructors.
func newSendDifficultyObj*(
  nonce: int,
  difficulty: uint32
): SendDifficulty {.inline, forceCheck: [].} =
  SendDifficulty(
    nonce: nonce,
    difficulty: difficulty
  )

func newSignedSendDifficultyObj*(
  nonce: int,
  difficulty: uint32
): SignedSendDifficulty {.inline, forceCheck: [].} =
  SignedSendDifficulty(
    nonce: nonce,
    difficulty: difficulty
  )
