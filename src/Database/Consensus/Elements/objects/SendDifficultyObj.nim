import ../../../../lib/Errors
import ../../../../Wallet/MinerWallet

import ElementObj
export ElementObj

type
  SendDifficulty* = ref object of BlockElement
    nonce*: int
    difficulty*: uint16

  SignedSendDifficulty* = ref object of SendDifficulty
    signature*: BLSSignature

func newSendDifficultyObj*(
  nonce: int,
  difficulty: uint16
): SendDifficulty {.inline, forceCheck: [].} =
  SendDifficulty(
    nonce: nonce,
    difficulty: difficulty
  )

func newSignedSendDifficultyObj*(
  nonce: int,
  difficulty: uint16
): SignedSendDifficulty {.inline, forceCheck: [].} =
  SignedSendDifficulty(
    nonce: nonce,
    difficulty: difficulty
  )
