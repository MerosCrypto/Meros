import ./BN

import times

proc getTime*(): BN =
    result = newBN($((uint32) epochTime())) #Replace before 2038.
