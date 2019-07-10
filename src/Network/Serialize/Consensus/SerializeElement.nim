#Errors lib.
import ../../../lib/Errors

#Element object.
import ../../../Database/Consensus/objects/ElementObj

#Base serialize functions.
method serialize*(
    element: Element
): string {.base, forceCheck: [].} =
    doAssert(false, "Element serialize method called.")

method serializeSign*(
    element: Element
): string {.base, forceCheck: [].} =
    doAssert(false, "Element serializeSign method called.")

method signedSerialize*(
    element: Element
): string {.base, forceCheck:[].} =
    doAssert(false, "Element signedSerialize method called.")

#Serialize a Verification for a MeritRemoval.
method serializeRemoval*(
    element: Element
): string {.base, forceCheck: [].} =
    doAssert(false, "Element serializeRemoval method called.")
