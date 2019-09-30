#Errors lib.
import ../../../../lib/objects/ErrorsObjs

#MinerWallet lib.
import ../../../../Wallet/MinerWallet

#Element lib.
import ElementObj
export ElementObj

#Finals lib.
import finals

#MeritRemoval objects.
finalsd:
    type
        MeritRemoval* = ref object of Element
            partial* {.final.}: bool
            element1* {.final.}: Element
            element2* {.final.}: Element

        SignedMeritRemoval* = ref object of MeritRemoval
            signature* {.final.}: BLSSignature

#Constructors.
func newMeritRemovalObj*(
    partial: bool,
    element1: Element,
    element2: Element
): MeritRemoval {.forceCheck: [].} =
    result = MeritRemoval(
        partial: partial,
        element1: element1,
        element2: element2
    )
    result.ffinalizePartial()
    result.ffinalizeElement1()
    result.ffinalizeElement2()

    try:
        result.holder = element1.holder
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a MeritRemoval: " & e.msg)

func newSignedMeritRemovalObj*(
    partial: bool,
    element1: Element,
    element2: Element,
    signature: BLSSignature
): SignedMeritRemoval {.forceCheck: [].} =
    result = SignedMeritRemoval(
        partial: partial,
        element1: element1,
        element2: element2,
        signature: signature
    )
    result.ffinalizePartial()
    result.ffinalizeElement1()
    result.ffinalizeElement2()
    result.ffinalizeSignature()

    try:
        result.holder = element1.holder
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a SignedMeritRemoval: " & e.msg)
