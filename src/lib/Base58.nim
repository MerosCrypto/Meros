import BN

import math, strutils

var Base58Characters: array[0 .. 57, char] = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J',
    'K', 'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X', 'Y', 'Z',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i',
    'j', 'k', 'm', 'n', 'o', 'p', 'q', 'r', 's',
    't', 'u', 'v', 'w', 'x', 'y', 'z'
]

var
    num0: BN = newBN("0")
    num1: BN = newBN("1")
    num58: BN = newBN("58")

proc verify*(base58Value: string): bool {.raises: [].} =
    result = true

    for i in 0 ..< base58Value.len:
        var ascii: int = (int) base58Value[i]
        if not (
            (47 < ascii and ascii < 58) or
            (64 < ascii and ascii < 73) or
            (73 < ascii and ascii < 79) or
            (79 < ascii and ascii < 91) or
            (96 < ascii and ascii < 108) or
            (108 < ascii and ascii < 123)
        ):
            result = false
            break

proc convert*(valueArg: BN): string {.raises: [OverflowError, Exception].} =
    if valueArg < num0:
        return

    var
        value: BN = valueArg
        remainder: string
    result = ""

    while value > num1:
        remainder = $(value mod num58)
        value = value div num58
        result = $Base58Characters[parseInt(remainder)] & result
    remainder = $(value mod num58)
    value = value div num58
    result = $Base58Characters[parseInt(remainder)] & result

    if value == num1:
        result = $Base58Characters[parseInt(remainder)] & result

    while result[0] == Base58Characters[0]:
        if result.len == 1:
            break
        result = result.substr(1, result.len)

proc revert*(base58Value: string): BN {.raises: [ValueError].} =
    if not verify(base58Value):
        raise newException(ValueError, "Invalid Base58 Number.")

    var
        digits: BN = newBN($base58Value.len)
        digitValue: int
        digitMultiple: BN
        value: BN = newBN("0")

    for i in 0 ..< base58Value.len:
        dec(digits)
        digitValue = (int) base58Value[i]
        if digitValue < 58:
            digitValue = digitValue - 49
        elif digitValue < 73:
            digitValue = digitValue - 56
        elif digitValue < 79:
            digitValue = digitValue - 57
        elif digitValue < 91:
            digitValue = digitValue - 58
        elif digitValue < 108:
            digitValue = digitValue - 64
        elif digitValue < 123:
            digitValue = digitValue - 65

        digitMultiple = num58 ^ digits
        value += newBN($digitValue) * digitMultiple

    return value
