import ./UInt

import times

proc getTime*(): UInt =
    result = newUInt($((uint32) epochTime()))
