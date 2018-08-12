import ./BN
import Util

import sets, sequtils

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

    digits255: OrderedSet[char] = mapLiterals([
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34,
        35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66,
        67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98,
        99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124,
        125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150,
        151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176,
        177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202,
        203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228,
        229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254,
        255
    ], char).toOrderedSet()

proc digits(base: int): OrderedSet[char] {.raises: [].} =
    result = digitsNo0OIl
    if base <= 24:
        result = digitsAll
    elif base <= 45:
        result = digitsNo0O
    elif base == 255:
        result = digits255

proc isBase*(value: string, base: int): bool {.raises: [].} =
    #Default value of true.
    result = true

    if base == 16:
        if (value.len mod 2) != 0:
            result = false
            return

    var loc: int
    for c in value:
        loc = base.digits.find(c)
        if loc == -1 or loc >= base:
            if (base == 16) and (('a' <= c) and (c <= 'f')):
                continue
            result = false
            return


proc toBN*(value: string, baseArg: int): BN {.raises: [ValueError].} =
    if not value.isBase(baseArg):
        raise newException(ValueError, "Invalid Base number.")

    result = newBN()
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

proc toString*(valueArg: BN, baseArg: int): string {.raises: [ValueError].} =
    var
        value: BN = valueArg
        base: BN = newBN(baseArg)

    if value == BNNums.ZERO:
        result = $baseArg.digits[0]
        if baseArg == 16:
            result = "00"
        return

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
