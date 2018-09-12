#Numerical libs.
import BN
import ../Base

#String utils standard lib.
import strutils

#Hash master type.
type Hash*[bits: static[int]] = object
    data*: array[bits div 8, uint8]

#To binary string.
proc toString*(hash: Hash): string =
    result = ""
    for b in hash.data:
        result &= char(b)

#To hex string.
proc `$`*(hash: Hash): string =
    result = ""
    for b in hash.data:
        result &= b.toHex()

#To BN.
proc toBN*(hash: Hash): BN =
    ($hash).toBN(16)

#Empty uint8 'array'.
var empty*: ptr uint8
