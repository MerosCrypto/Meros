#Errors lib.
import ../../../../lib/objects/ErrorsObjs

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

    SignedMeritRemoval* = ref object of MeritRemoval
        signature*: BLSSignature

#Constructors.
func newMeritRemovalObj*(
    nick: uint16,
    partial: bool,
    element1: Element,
    element2: Element
): MeritRemoval {.inline, forceCheck: [].} =
    MeritRemoval(
        holder: nick,
        partial: partial,
        element1: element1,
        element2: element2
    )

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
