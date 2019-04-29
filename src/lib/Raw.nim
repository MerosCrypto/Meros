#Errors lib.
import Errors

#BN lib.
import BN
export BN

#Math standard lib.
import math

#Base we're working with.
let BASE: BN = newBN(256)

#Turn a Raw string into a BN.
proc toBNFromRaw*(value: string): BN {.forceCheck: [].} =
    #Create a new BN.
    result = newBN()

    #Iterate over the value.
    for i, digit in value:
        #Result is the result plus (base raised to the digit location, multiplied by the value of the digit).
        result += (
            BASE ^ (value.len - i - 1)
        ) * newBN(int(digit))

#Convert the BN to its Raw string.
proc toRaw*(valueArg: BN): string {.forceCheck: [].} =
    #Copy the value.
    var value: BN = valueArg

    #If the value is zero, return 0.
    if value == newBN(0):
        return $char(0)

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
        result &= char(digit)
