#Errors lib.
import Errors

#BN lib.
import BN
export BN

#Math standard lib.
import math

#Base we're working with.
let BASE: BN = newBN(16)

#Hex characters.
const HEX: seq[char] = @[
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F'
]

#Verifies if a string is Hex or not.
func isHex*(value: string): bool {.forceCheck: [].} =
    #Default value of true.
    result = true

    #If the value isn't double padded, reutn false.
    if (value.len mod 2) != 0:
        return false

    #Location of the digit.
    var loc: int
    #Iterate through every digit in the string value.
    for digit in value:
        #Get the location of the digit.
        loc = HEX.find(digit)
        #If the digit wasn't found...
        if loc == -1:
            #Allow 'a' through 'f' (even though we use 'A' through 'F').
            if ('a' <= digit) and (digit <= 'f'):
                continue
            #Return false.
            return false

#Turn a Hex string into a BN.
proc toBNFromHex*(valueArg: string): BN {.forceCheck: [ValueError].} =
    #If the value isn't of the base, raise a ValueError.
    if not valueArg.isHex():
        raise newException(ValueError, "Invalid Hex number.")

    #Create a new BN.
    result = newBN()
    #Copy the value.
    var value: string = valueArg

    #Iterate over the value and replace lower case chars with upper case chars.
    for i, c in value:
        if ('a' <= c) and (c <= 'f'):
            value[i] = char(int(c) - int('a') + int('A'))

    #Iterate over the value.
    for i, digit in value:
        #Result is the result plus (base raised to the digit location, multiplied by the value of the digit).
        result += (
            BASE ^ (value.len - i - 1)
        ) * newBN(HEX.find(digit))

#Convert the BN to its Hex string.
proc toHex*(valueArg: BN): string {.forceCheck: [].} =
    #Copy the value.
    var value: BN = valueArg

    #If the value is zero, return a double 0.
    if value == newBN(0):
        return "00"

    #Create the power, numDigits, place, and digit variables.
    var
        power: BN = newBN(1)
        numDigits: int = -1
        place: BN
        digit: int

    #While the power is less then the value...
    while power <= value:
        #Multiply the power by the base and increase the number of digits.
        power *= BASE
        inc(numDigits)

    #Count down from the number of digits to 0.
    for i in countDown(numDigits, 0):
        #Set the place to the base raised to the digit location.
        place = BASE ^ i
        #Set the digit to the value divided by the place.
        digit = (value / place).toInt()
        #Remove the place from the value.
        value = value mod place
        #Ad the new digit to the result.
        result &= HEX[digit]

    #If the length isn't even, pad it so it is.
    if result.len mod 2 == 1:
        result = "0" & result
