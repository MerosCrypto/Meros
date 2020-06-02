import ../../../../lib/objects/ErrorsObjs
import ../../../../lib/Hash/objects/HashObj
import ../../../../Wallet/MinerWallet

import ElementObj
export ElementObj

type
  MeritRemoval* = ref object of BlockElement
    partial*: bool
    element1*: Element
    element2*: Element
    reason*: Hash[256]

  SignedMeritRemoval* = ref object of MeritRemoval
    signature*: BLSSignature

func newMeritRemovalObj*(
  nick: uint16,
  partial: bool,
  element1: Element,
  element2: Element,
  reason: Hash[256]
): MeritRemoval {.inline, forceCheck: [].} =
  MeritRemoval(
    holder: nick,
    partial: partial,
    element1: element1,
    element2: element2,
    reason: reason
  )

func newSignedMeritRemovalObj*(
  nick: uint16,
  partial: bool,
  element1: Element,
  element2: Element,
  reason: Hash[256],
  signature: BLSSignature
): SignedMeritRemoval {.inline, forceCheck: [].} =
  result = SignedMeritRemoval(
    holder: nick,
    partial: partial,
    element1: element1,
    element2: element2,
    reason: reason,
    signature: signature
  )
