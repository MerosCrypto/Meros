#Wrapper around the Nim time library that returns a BN.

import BN

import times, strutils

#Get time function. Just turns the epoch into a string and makes a BN off it
proc getTime*(): BN =
    result = newBN(($(epochTime())).split(".")[0])
