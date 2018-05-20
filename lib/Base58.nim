import math

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
    num0: uint32 = 0
    num1: uint32 = 1
    num58: uint32 = 58

proc verify*(base58Value: string) =
    for i in 0 ..< base58Value.len:
        var ascii: int = (int) base58Value[i]
        if 48 < ascii and ascii < 58:
            discard
        elif 64 < ascii and ascii < 73:
            discard
        elif 73 < ascii and ascii < 79:
            discard
        elif 79 < ascii and ascii < 91:
            discard
        elif 96 < ascii and ascii < 108:
            discard
        elif 108 < ascii and ascii < 123:
            discard
        else:
            raise newException(Exception, "Invalid Base58 Number")

proc convert*(valueArg: uint32): string =
    if valueArg < num0:
        return

    var
        value: uint32 = valueArg
        remainder: uint32
    result = ""

    while value > num1:
        remainder = value mod num58
        value = value div num58
        result = $Base58Characters[remainder] & result
    remainder = value mod num58
    value = value div num58
    result = $Base58Characters[remainder] & result

    if value == num1:
        result = $Base58Characters[remainder] & result

    while result[0] == Base58Characters[0]:
        if result.len == 1:
            break
        result = result.substr(1, result.len)

proc revert*(base58Value: string): uint32 =
    verify(base58Value)

    var
        digits: uint32 = (uint32) base58Value.len
        digitValue: uint32
        digitMultiple: uint32
        value: uint32 = 0

    for i in 0 .. base58Value.len:
        dec(digits)
        digitValue = (uint32) base58Value[i]
        if digitValue < num58:
            digitValue = digitValue - (uint32) 49
        elif digitValue < (uint32) 73:
            digitValue = digitValue - (uint32) 56
        elif digitValue < (uint32) 79:
            digitValue = digitValue - (uint32) 57
        elif digitValue < (uint32) 91:
            digitValue = digitValue - (uint32) 58
        elif digitValue < (uint32) 108:
            digitValue = digitValue - (uint32) 64
        elif digitValue < (uint32) 123:
            digitValue = digitValue - (uint32) 65

        digitMultiple = num58 ^ digits
        value += digitValue * digitMultiple

    return value
