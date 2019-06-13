import ../../../lib/Errors

import ../../../Database/Consensus/objects/ElementObj

import ../SerializeCommon

method serialize*(
    element: Element,
    signingOrVerifying: bool = false
): string {.base, forceCheck: [].} =
    doAssert(false, "Unimplemented base method")
