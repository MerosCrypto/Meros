#Wrapper around the Nim time library that returns a BN.

#Times standard lib.
import times

#Gets the epoch.
func getTime*(): int {.raises: [].} =
    int(times.getTime().toUnix())
