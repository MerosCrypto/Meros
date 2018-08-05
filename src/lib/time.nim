#Wrapper around the Nim time library that returns a BN.

import ../lib/BN

import times, strutils

#Get time function. Just turns the epoch into a string and makes a BN off it.
proc getTime*(): BN {.raises: [AssertionError].} =
    result = newBN(($(epochTime())).split(".")[0])
