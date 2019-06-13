import ../../../lib/Errors

import ../../../Database/Consensus/objects/ElementObj

import ../SerializeCommon

method serialize*(
    element: Element,
    signingOrVerifying: bool = false
): string {.forceCheck: [].} = # {.base, forceCheck: [].}--forceCheck currently incompatible with .base.
    doAssert(false, "Unimplemented base method")
