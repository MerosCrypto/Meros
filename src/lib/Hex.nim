import BN

import math, strutils

var Base16Characters: array[16, char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'a', 'b', 'c', 'd', 'e', 'f'
]

var Base16Set: set[char] = {
    '0' .. '9',
    'A' .. 'F',
    'a' .. 'f'
}

var
    num0: BN = newBN("0")
    num1: BN = newBN("1")
    num16: BN = newBN("16")

proc verify*(value: string): bool {.raises: [].} =
    result = true

    for i in 0 ..< value.len:
        if value[i] notin Base16Set:
            result = false
            break

proc convert*(valueArg: BN): string {.raises: [OverflowError, Exception].} =
    if valueArg < num0:
        raise newException(ValueError, "BN is negative.")

    var
        value: BN = valueArg
        remainder: string
    result = ""

    while value > num1:
        remainder = $(value mod num16)
        value = value / num16
        result = $Base16Characters[parseInt(remainder)] & result
    remainder = $(value mod num16)
    value = value / num16
    result = $Base16Characters[parseInt(remainder)] & result

    if value == num1:
        result = $Base16Characters[parseInt(remainder)] & result

    while result[0] == Base16Characters[0]:
        if result.len == 1:
            break
        result = result.substr(1, result.len)

    if result.len mod 2 == 1:
        result = "0" & result

proc revert*(base16Value: string): BN {.raises: [ValueError].} =
    if not verify(base16Value):
        raise newException(ValueError, "Invalid Hex Number.")

    var
        digits: BN = newBN($base16Value.len)
        value: int
    result = newBN("0")

    for i in 0 ..< base16Value.len:
        dec(digits)
        value = (int) base16Value[i]
        if value < 58:
            value = value - 48
        elif value < 71:
            value = value - 55
        else:
            value = value - 87

        result += newBN($value) * (num16 ^ digits)
