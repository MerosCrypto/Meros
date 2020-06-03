import ../../../lib/Errors

import ../../../Database/Consensus/Elements/objects/ElementObj

#Base serialize functions.
#These should never be called.
method serialize*(
  element: Element
): string {.base, forceCheck: [].} =
  panic("Element serialize base method called.")

method serializeWithoutHolder*(
  element: Element
): string {.base, forceCheck: [].} =
  panic("Element serializeWithoutHolder base method called.")

method serializeContents*(
  element: Element
): string {.base, forceCheck: [].} =
  panic("Element serializeContents base method called.")

method signedSerialize*(
  element: Element
): string {.base, forceCheck:[].} =
  panic("Element signedSerialize base method called.")
