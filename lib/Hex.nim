import ./UInt

import math, strutils

var Base16Characters: array[0 .. 15, char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'a', 'b', 'c', 'd', 'e', 'f'
]

var
    num0: UInt = newUInt("0")
    num1: UInt = newUInt("1")
    num16: UInt = newUInt("16")

proc verify*(base16Value: string) =
    for i in 0 ..< base16Value.len:
        var ascii: int = (int) base16Value[i]
        if 47 < ascii and ascii < 58:
            discard
        elif 64 < ascii and ascii < 70:
            discard
        elif 96 < ascii and ascii < 103:
            discard
        else:
            raise newException(Exception, "Invalid Hex Number")

proc convert*(valueArg: UInt): string =
    if valueArg < num0:
        return

    var
        value: UInt = valueArg
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

proc revert*(base16Value: string): UInt =
    verify(base16Value)

    var
        digits: UInt = newUInt($base16Value.len)
        digitValue: int
        digitMultiple: UInt
        value: UInt = newUInt("0")

    for i in 0 ..< base16Value.len:
        dec(digits)
        digitValue = ((int) base16Value[i])
        if digitValue < 58:
            digitValue = digitValue - 48
        elif digitValue < 71:
            digitValue = digitValue - 55
        else:
            digitValue = digitValue - 87
        digitMultiple = num16 ^ digits
        value += newUInt($digitValue) * digitMultiple

    return value
