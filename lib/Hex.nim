import math

var Base16Characters: array[0 .. 15, char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'a', 'b', 'c', 'd', 'e', 'f'
]

var
    num0: uint32 = 0
    num1: uint32 = 1
    num16: uint32 = 16

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

proc convert*(valueArg: uint32): string =
    if valueArg < num0:
        return

    var
        value: uint32 = valueArg
        remainder: uint32
    result = ""

    while value > num1:
        remainder = value mod num16
        value = value div num16
        result = $Base16Characters[remainder] & result
    remainder = value mod num16
    value = value div num16
    result = $Base16Characters[remainder] & result

    if value == num1:
        result = $Base16Characters[remainder] & result

    if result.len > 1:
        while result[0] == Base16Characters[0]:
            result = result.substr(1, result.len)

    if result.len mod 2 == 1:
        result = "0" & result

proc revert*(base16Value: string): uint32 =
    verify(base16Value)

    var
        digits: uint32 = (uint32) base16Value.len
        digitValue: uint32
        digitMultiple: uint32
        value: uint32 = 0

    for i in 0 ..< base16Value.len:
        dec(digits)
        digitValue = (uint32) base16Value[i]
        if digitValue < (uint32) 58:
            digitValue = digitValue - (uint32) 48
        elif digitValue < (uint32) 71:
            digitValue = digitValue - (uint32) 55
        else:
            digitValue = digitValue - (uint32) 87
        digitMultiple = num16 ^ digits
        value += digitValue * digitMultiple

    return value
