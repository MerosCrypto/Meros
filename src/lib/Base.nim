import BN
import sets
import math
import strutils
import util

const digits = toOrderedSet([
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
])

proc isBase*(value: string, base: int): bool {.raises: [].} =
    for c in value:
        let loc = digits.find(c)
        if loc == -1 or loc >= base:
            return false
    return true

proc toString*(value: BN, base: int): string {.raises: [OverflowError, ValueError].} =
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
        result.add(digits[parseInt($dig)])  # TODO need a dedicated toInt(BN)

proc toBN*(encoded: string, base: int): BN {.raises: [ValueError].} =
    if not encoded.isBase(base):
        raise newException(ValueError, "Given string is not a valid base $# number." % $base)

    var intVal = 0
    for i, dig in encoded:
        intVal += base^(encoded.len - i - 1) * digits.find(dig)

    return newBN(intVal)
