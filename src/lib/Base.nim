import BN
import Util

import sets

const
    digitsAll: OrderedSet[char] = [
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N'
    ].toOrderedSet()

    digitsNo0O: OrderedSet[char] = [
             '1', '2', '3', '4', '5', '6', '7', '8', '9',
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N',      'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
        'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k'
    ].toOrderedSet()

    digitsNo0OIl: OrderedSet[char] = [
             '1', '2', '3', '4', '5', '6', '7', '8', '9',
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',      'J', 'K', 'L', 'M', 'N',      'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
        'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k',      'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
    ].toOrderedSet()

proc digits(base: int): OrderedSet[char] {.raises: [].} =
    if base <= 24:
        return digitsAll
    elif base <= 45:
        return digitsNo0O
    return digitsNo0OIl

proc isBase*(value: string, base: int): bool {.raises: [].} =
    if base == 16:
        if (value.len mod 2) != 0:
            return false

    var loc: int
    for c in value:
        loc = base.digits.find(c)
        if loc == -1 or loc >= base:
            if (base == 16) and (('a' <= c) and (c <= 'f')):
                continue
            return false
    return true


proc toBN*(value: string, baseArg: int): BN {.raises: [ValueError].} =
    if not value.isBase(baseArg):
        raise newException(ValueError, "Invalid Base number.")

    result = newBN(0)
    var
        base: BN = newBN(baseArg)
        digit: char
    for i in 0 ..< value.len:
        digit = value[i]
        if (baseArg == 16) and (('a' <= digit) and (digit <= 'f')):
            digit = (char) ord(digit) - ord('a') + ord('A')

        result +=
            (
                base ^
                newBN(value.len - i - 1)
            ) * newBN(baseArg.digits.find(value[i]))

proc toString*(valueArg: BN, baseArg: int): string {.raises: [ValueError, OverflowError].} =
    var
        value: BN = valueArg
        base: BN = newBN(baseArg)

    if value == BNNums.ZERO:
        if baseArg == 16:
            return "00"
        return $baseArg.digits[0]

    var
        power: BN = newBN(1)
        numDigits: int = 1
    while power <= value:
        power = power * base
        inc(numDigits)
    numDigits -= 2

    result = ""
    var
        place: BN
        digit: int
    for i in countDown(numDigits, 0):
        place = base ^ newBN(i)
        digit = (value div place).toInt()
        value = value mod place
        result.add(baseArg.digits[digit])

    if baseArg == 16:
        if (result.len mod 2) == 1:
            result = "0" & result
