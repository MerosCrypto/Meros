import ../../../lib/Errors

import ../../../lib/Hash

import finals

import ElementObj

finalsd:
    type
        MeritRemoval* = ref object of Element
            element1* {.final.}: Element
            element2* {.final.}: Element

        SignedMeritRemoval* = ref object of MeritRemoval
            signature* {.final.}: BLSSignature

func newMeritRemoval*(
    element1: Element,
    element2: Element
): MeritRemoval {.forceCheck: [].} =
    result = MeritRemoval(
        element1: element1,
        element2: element2
    )
    result.ffinalizeElement1()
    result.ffainlizeElement2()

func newSignedMeritRemoval*(
    element1: Element,
    element2: Element
): SignedMeritRemoval {.forceCheck: [].} =
    result = SignedMeritRemoval(
        element1: element1,
        element2: element2
    )
    result.ffinalizeElement1()
    result.ffainlizeElement2()
