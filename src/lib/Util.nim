#Errors lib.
import Errors

#Times standard lib.
import times

#String utils standard lib.
import strutils
#Export the commonly used int/hex functions from it.
export parseInt, parseUInt
export toHex, parseHexInt, parseHexStr

#Nimcrypto lib (for secure RNG).
import nimcrypto

#Gets the epoch and returns it as a Time.
proc getTime*(): uint32 {.inline, forceCheck: [].} =
    uint32(times.getTime().toUnix())

#Left-pads data, with a char or string, until the data is a certain length.
func pad*(
    data: char or string,
    len: int,
    prefix: char or string = char(0)
): string {.forceCheck: [].} =
    result = $data

    while result.len < len:
        result = prefix & result

#Reverse a string.
func reverse*(
    data: string
) : string {.forceCheck: [].} =
    result = newString(data.len)
    for i in 0 ..< data.len:
        result[data.len - 1 - i] = data[i]

#Converts a number to a binary string.
func toBinary*(
    number: SomeNumber
): string {.forceCheck: [].} =
    var
        #Get the bytes of the number.
        bytes: int = sizeof(number)
        #Init the shift counters.
        left: int = -8
        right: int = bytes * 8
        #Have we encountered a non 0 byte yet?
        filler: bool = true

    #Iterate over each byte.
    for i in 0 ..< bytes:
        #Update left/right.
        left += 8
        right -= 8

        #Clear the left side, shift it back, and clear the right side.
        var b: int = int(number shl left shr (left + right))

        #If we haven't hit a non-0 byte...
        if filler:
            #And this is a 0 byte...
            if b == 0:
                #Continue.
                continue
            #Else, mark that we have hit a 0 byte.
            filler = false

        #Put the byte in the string.
        result &= char(b)

#Converts a binary char/string to a number.
func fromBinary*(
    number: char
): int {.inline, forceCheck: [].} =
    int(number)

func fromBinary*(
    number: string
): int {.forceCheck: [].} =
    #Iterate over each byte.
    for b in 0 ..< number.len:
        #Add the byte after it's been properly shifted.
        result += int(number[b]) shl ((number.len - b - 1) * 8)

#Extract a set of bits.
func extractBits*(
    data: uint16,
    start: int,
    bits: int
): uint16 {.forceCheck: [].} =
    (data shl start) shr (16 - bits)

#Extract a set of bits.
func extractBits*(
    data: uint32,
    start: int,
    bits: int
): uint32 {.forceCheck: [].} =
    (data shl start) shr (32 - bits)

#Securely generates X random bytes,
proc randomFill*[T](
    arr: var openArray[T]
) {.forceCheck: [
    RandomError
].} =
    try:
        if randomBytes(arr) != arr.len:
            raise newException(Exception, "")
    except Exception:
        raise newException(RandomError, "Couldn't randomly fill the passed array.")
