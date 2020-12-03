import ../../../../lib/objects/ErrorObjs
import ../../../../Wallet/MinerWallet

import ElementObj
export ElementObj

type SignedMeritRemoval* = ref object of MeritRemovalParent
  holder*: uint16
  partial*: bool
  element1*: Element
  element2*: Element
  signature*: BLSSignature

func newSignedMeritRemovalObj*(
  nick: uint16,
  partial: bool,
  element1: Element,
  element2: Element,
  signature: BLSSignature
): SignedMeritRemoval {.inline, forceCheck: [].} =
  result = SignedMeritRemoval(
    holder: nick,
    partial: partial,
    element1: element1,
    element2: element2,
    signature: signature
  )
