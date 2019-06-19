#Errors lib.
import ../../../lib/Errors

#Element object.
import ../../../Database/Consensus/objects/ElementObj

#Base serialize functions.
method serialize*(
    element: Element
): string {.base, forceCheck: [].} =
    doAssert(false, "Element serialize method called.")

method serializeSignature*(
    element: Element
): string {.base, forceCheck: [].} =
    doAssert(false, "Element serializeSignature method called.")

method signedSerialize*(
    element: Element
): string {.base, forceCheck:[].} =
    doAssert(false, "Element signedSerialize method called.")
