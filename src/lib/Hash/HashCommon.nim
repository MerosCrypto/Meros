#Errors lib.
import ../Errors

#Util lib.
import ../Util

#BN/Raw lib.
import ../Raw

#Hash master type.
type Hash*[bits: static[int]] = object
    data*: array[bits div 8, uint8]

#Empty uint8 'array'.
var EmptyHash*: ptr uint8

#toHash function.
func toHash*(
    hash: string,
    bits: static[int]
): Hash[bits] {.forceCheck: [
    ValueError
].} =
    if hash.len == bits div 8:
        for i in 0 ..< hash.len:
            result.data[i] = uint8(hash[i])
    elif hash.len div 2 == bits div 8:
        for i in countup(0, hash.len - 1, 2):
            result.data[i div 2] = uint8(parseHexInt(hash[i .. i + 1]))
    else:
        raise newException(ValueError, "toHash not handed the right amount of data.")

#To binary string.
func toString*(
    hash: Hash
): string {.forceCheck: [].} =
    for b in hash.data:
        result &= char(b)

#To hex string.
func `$`*(
    hash: Hash
): string {.forceCheck: [].} =
    for b in hash.data:
        result &= b.toHex()

#To BN.
proc toBN*(
    hash: Hash
): BN {.inline, forceCheck: [].} =
    hash.toString().toBNFromRaw()
