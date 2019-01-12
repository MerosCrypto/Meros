#BN lib.
import BN

#mapLiterals which enables using the raw ASCII values instead of the characters.
import sequtils

#Bases.
const
    Hex: seq[char] = @[
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
        'A', 'B', 'C', 'D', 'E', 'F'
    ]

    Raw: seq[char] = mapLiterals(@[
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
        21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
        40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58,
        59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77,
        78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96,
        97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112,
        113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128,
        129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144,
        145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160,
        161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176,
        177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192,
        193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208,
        209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224,
        225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240,
        241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255
    ], char)

#Gets the digits behind a base.
func digits(base: int): seq[char] {.raises: [].} =
    #IF the base is 16 or below...
    if base <= 16:
        return Hex
    #If the base is 256...
    elif base == 256:
        return Raw

#Verifies a string is of a certain base.
func isBase*(value: string, base: int): bool {.raises: [].} =
    #Default value of true.
    result = true

    #If its Hex, but the value isn't double padded, retuurn false.
    if base == 16:
        if (value.len mod 2) != 0:
            return false

    var
        #Location of the digit.
        loc: int
        #Digits.
        digits: seq[char] = base.digits
    #Iterate through every digit in the string value.
    for digit in value:
        #Get the location of the digit.
        loc = digits.find(digit)
        #If the digit wasn't found or its location is outside of the base...
        if loc == -1 or base <= loc:
            #Allow 'a' through 'f' in Hex strings (even though the base is 'A' through 'F').
            if (base == 16) and (('a' <= digit) and (digit <= 'f')):
                continue
            #Return false.
            return false

#Turn a string into a BN.
func toBN*(valueArg: string, baseArg: int): BN {.raises: [ValueError].} =
    #If the value isn't of the base...
    if not valueArg.isBase(baseArg):
        #Throw a ValueError.
        raise newException(ValueError, "Invalid Base number.")

    #Create a new BN.
    result = newBN()
    var
        #Copy the value/base out of the arguments.
        value: string = valueArg
        base: BN = newBN(baseArg)
        #Get the digits of the base.
        digits: seq[char] = baseArg.digits

    #If it's Hex...
    if baseArg == 16:
        #Iterate over the value and replace lower case chars with upper case chars.
        for i, c in value:
            if ('a' <= c) and (c <= 'f'):
                value[i] = (char) ord(c) - ord('a') + ord('A')

    #Iterate over the value.
    for i, digit in value:
        #Result is the result plus (base raised to the digit location, multiplied by the value of the digit in the base).
        result +=
            (
                base ^
                (value.len - i - 1)
            ) * newBN(digits.find(digit))

#Convert a value to a string (in the specified base).
proc toString*(valueArg: BN, baseArg: int): string {.raises: [].} =
    var
        #Extract the value and base from the arguments.
        value: BN = valueArg
        base: BN = newBN(baseArg)
        digits = baseArg.digits

    #If the value is zero, set the result to the 0 of the base.
    if value == newBN(0):
        #If the base arg is 16, double pad it.
        if baseArg == 16:
            return "00"
        return $digits[0]

    #Create the power, numDigits, place, and digit variables.
    var
        power: BN = newBN(1)
        numDigits: int = -1
        place: BN
        digit: int

    #While the power is less then the value...
    while power <= value:
        #Multiply the power by the base and increase the number of digits.
        power *= base
        inc(numDigits)

    #Set the result to a new string.
    result = ""
    #Count down from the number of digits to 0.
    for i in countDown(numDigits, 0):
        #Set the place to the base raised to the digit location.
        place = base ^ i
        #Set the digit to the value divided by the place.
        digit = (value / place).toInt()
        #Remove the place from the value.
        value = value mod place
        #Ad the new digit to the result.
        result &= digits[digit]

    #If it's Hex, and it's not double padded, prefix a 0.
    if baseArg == 16:
        if (result.len mod 2) == 1:
            result = "0" & result
