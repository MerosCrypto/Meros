#Element lib.
import ElementObj
export ElementObj

#ForceCheck libs.
#We generally get this from Errors yet can't as Errors imports this.
import ForceCheck

#Finals lib.
import finals

#BLS Nimble package.
#It's atrocious to directly import this.
#We should import MinerWallet, or at least BLS.
#That said, both use Errors which imports this.
import mc_bls

#MeritRemoval objects.
finalsd:
    type
        MeritRemoval* = ref object of Element
            partial* {.final.}: bool
            element1* {.final.}: Element
            element2* {.final.}: Element

        SignedMeritRemoval* = ref object of MeritRemoval
            signature* {.final.}: Signature

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
    signature: Signature
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
