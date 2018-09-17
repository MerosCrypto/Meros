#Numerical libs.
import BN
import ../Base

#String utils standard lib.
import strutils

#Hash master type.
type Hash*[bits: static[int]] = object
    data*: array[bits div 8, uint8]

#toHash function.
proc toHash*(hash: string, bits: static[int]): Hash[bits] {.raises: [ValueError].} =
    if hash.len == bits div 8:
        for i in 0 ..< hash.len:
            result.data[i] = uint8(hash[i])
    elif hash.len div 2 == bits div 8:
        for i in countup(0, hash.len - 1, 2):
            result.data[i div 2] = uint8(parseHexInt(hash[i .. i + 1]))
    else:
        raise newException(ValueError, "toHash not handled the right amount of data.")

#To binary string.
proc toString*(hash: Hash): string {.raises: [].} =
    result = ""
    for b in hash.data:
        result &= char(b)

#To hex string.
proc `$`*(hash: Hash): string  {.raises: [].} =
    result = ""
    for b in hash.data:
        result &= b.toHex()

#To BN.
proc toBN*(hash: Hash): BN  {.raises: [ValueError].} =
    ($hash).toBN(16)

#Empty uint8 'array'.
var EmptyHash*: ptr uint8
