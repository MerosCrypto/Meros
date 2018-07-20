import BN
import sets
import math
import strutils
import algorithm
import util

const digitsAll = toOrderedSet([
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N'
])
const digitsNo0O = toOrderedSet([
         '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N',      'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k'
])
const digitsNo0OIl = toOrderedSet([
         '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',      'J', 'K', 'L', 'M', 'N',      'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k',      'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
])

func digits(base: int): OrderedSet[char] =
    if base <= 24:
        return digitsAll
    elif base <= 45:
        return digitsNo0O
    return digitsNo0OIl

proc isBase*(value: string, base: int): bool {.raises: [].} =
    for c in value:
        let loc = base.digits.find(c)
        if loc == -1 or loc >= base:
            return false
    return true

proc toString*(value: BN, base: int): string {.raises: [OverflowError, ValueError].} =
    # Quickfail for 0, which doesn't work with the algorithm
    if value == newBN(0):
        return $base.digits[0]


    let baseBN = newBN(base)
    let nDigits = block:
        var power = newBN(1)
        var digCount = 1
        while power <= value:
            power *= baseBN
            inc(digCount)
        digCount - 1

    result = ""
    var value = value
    for i in countDown(nDigits - 1, 0):
        let base_to_i_BN = newBN(base^i)
        let dig = value div base_to_i_BN
        value = value mod base_to_i_BN
        result.add(base.digits[parseInt($dig)])  # TODO need a dedicated toInt(BN)

proc toBN*(encoded: string, base: int): BN {.raises: [ValueError].} =
    if not encoded.isBase(base):
        raise newException(ValueError, "Given string is not a valid base $# number." % $base)

    let base_BN = newBN(base)
    result = newBN(0)
    for i, dig in encoded:
        result += base_BN^newBN(encoded.len - i - 1) * newBN(base.digits.find(dig))
