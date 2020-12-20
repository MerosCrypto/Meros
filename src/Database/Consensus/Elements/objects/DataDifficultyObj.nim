import ../../../../lib/Errors
import ../../../../Wallet/MinerWallet

import ElementObj
export ElementObj

type
  DataDifficulty* = ref object of BlockElement
    nonce*: int
    difficulty*: uint16

  SignedDataDifficulty* = ref object of DataDifficulty
    signature*: BLSSignature

func newDataDifficultyObj*(
  nonce: int,
  difficulty: uint16
): DataDifficulty {.inline, forceCheck: [].} =
  DataDifficulty(
    nonce: nonce,
    difficulty: difficulty
  )

func newSignedDataDifficultyObj*(
  nonce: int,
  difficulty: uint16
): SignedDataDifficulty {.inline, forceCheck: [].} =
  SignedDataDifficulty(
    nonce: nonce,
    difficulty: difficulty
  )
