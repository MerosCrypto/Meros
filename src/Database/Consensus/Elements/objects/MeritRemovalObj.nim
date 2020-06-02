#Errors lib.
import ../../../../lib/objects/ErrorsObjs

#Hash object.
import ../../../../lib/Hash/objects/HashObj

#MinerWallet lib.
import ../../../../Wallet/MinerWallet

#Element objects.
import ElementObj
export ElementObj

#MeritRemoval objects.
type
  MeritRemoval* = ref object of BlockElement
    partial*: bool
    element1*: Element
    element2*: Element
    reason*: Hash[256]

  SignedMeritRemoval* = ref object of MeritRemoval
    signature*: BLSSignature

#Constructors.
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
