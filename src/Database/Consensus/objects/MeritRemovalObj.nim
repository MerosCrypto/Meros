import ../../../lib/Errors

import ../../../Wallet/BLS

import ../../../lib/Hash

import finals

import ElementObj
export ElementObj

finalsd:
    type
        MeritRemoval* = ref object of Element
            element1* {.final.}: Element
            element2* {.final.}: Element

        SignedMeritRemoval* = ref object of MeritRemoval
            signature* {.final.}: BLSSignature

func newMeritRemovalObj*(
    element1: Element,
    element2: Element
): MeritRemoval {.forceCheck: [].} =
    result = MeritRemoval(
        element1: element1,
        element2: element2
    )
    result.ffinalizeElement1()
    result.ffainlizeElement2()

func newSignedMeritRemovalObj*(
    element1: Element,
    element2: Element
): SignedMeritRemoval {.forceCheck: [].} =
    result = SignedMeritRemoval(
        element1: element1,
        element2: element2
    )
    result.ffinalizeElement1()
    result.ffainlizeElement2()
