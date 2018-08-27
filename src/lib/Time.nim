#Wrapper around the Nim time library that returns a BN.

#BN lib.
import ./BN

#Times standard lib.
import times

#Get time function. Just turns the epoch into a string and makes a BN off it.
proc getTime*(): BN {.raises: [].} =
    result = newBN(
        int(times.getTime().toUnix())
    )
