#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element lib.
import ElementObj
export ElementObj

#Finals lib.
import finals

#MeritRemoval objects.
finalsd:
    type
        MeritRemoval* = ref object of Element
            element1* {.final.}: Element
            element2* {.final.}: Element

        SignedMeritRemoval* = ref object of MeritRemoval
            signature* {.final.}: BLSSignature

#Constructors.
func newMeritRemovalObj*(
    nonce: int,
    element1: Element,
    element2: Element
): MeritRemoval {.forceCheck: [].} =
    result = MeritRemoval(
        element1: element1,
        element2: element2
    )
    result.ffinalizeElement1()
    result.ffinalizeElement2()

    try:
        result.holder = element1.holder
        result.nonce = nonce
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a MeritRemoval: " & e.msg)

func newSignedMeritRemovalObj*(
    nonce: int,
    element1: Element,
    element2: Element,
    signature: BLSSignature
): SignedMeritRemoval {.forceCheck: [].} =
    result = SignedMeritRemoval(
        element1: element1,
        element2: element2,
        signature: signature
    )
    result.ffinalizeElement1()
    result.ffinalizeElement2()
    result.ffinalizeSignature()

    try:
        result.holder = element1.holder
        result.nonce = nonce
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a SignedMeritRemoval: " & e.msg)
