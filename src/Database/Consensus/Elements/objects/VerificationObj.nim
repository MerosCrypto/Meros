import ../../../../lib/Errors
import ../../../../lib/Hash
import ../../../../Wallet/MinerWallet

import ElementObj
export ElementObj

type
  Verification* = ref object of Element
    holder*: uint16
    hash*: Hash[256]

  SignedVerification* = ref object of Verification
    signature*: BLSSignature

func newVerificationObj*(
  hash: Hash[256]
): Verification {.inline, forceCheck: [].} =
  Verification(
    hash: hash
  )

func newSignedVerificationObj*(
  hash: Hash[256]
): SignedVerification {.inline, forceCheck: [].} =
  SignedVerification(
    hash: hash
  )
