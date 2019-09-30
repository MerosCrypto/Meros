#Errors lib.
import ../../../lib/Errors

#Element object.
import ../../../Database/Consensus/Elements/objects/ElementObj

#Base serialize functions.
method serialize*(
    element: Element
): string {.base, forceCheck: [].} =
    doAssert(false, "Element serialize method called.")

method serializeWithoutHolder*(
    element: Element
): string {.base, forceCheck: [].} =
    doAssert(false, "Element serializeSign method called.")

method signedSerialize*(
    element: Element
): string {.base, forceCheck:[].} =
    doAssert(false, "Element signedSerialize method called.")
