#Errors lib.
import Errors

#Util lib.
import Util

#Math standard lib.
import math

#Seq utils standard lib.
import sequtils

#Base32 characters.
const CHARACTERS: string = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

#Define the Base32 type.
type Base32* = distinct seq[uint8]

#Checks if the string is a valid Base32 string.
func isBase32*(
    data: string
): bool {.forceCheck: [].} =
    #Default return value of true.
    result = true

    #Iterate over the data.
    for i in data:
        #If the character is not in the character set...
        if CHARACTERS.find(i) == -1:
            #Return false.
            return false

#Binary array to Base32 object.
func toBase32*(
    data: openArray[uint8]
): Base32 {.forceCheck: [].} =
    if data.len == 0:
        return

    #Creae a result variable.
    var res: seq[uint8] = @[]

    var
        #How many times to run the loop.
        count: int = int(
            ceil(
                (data.len * 8) / 5
            )
        )
        #Base256 bit we're on.
        bit: int = 0
        #Base256 byte we're on.
        i: int
        #Temporary variable for the data.
        temp: uint16

    #For each 5 bit variable...
    for _ in 0 ..< count:
        #Set the byte.
        i = bit div 8

        #Set temp.
        temp = uint16(data[i]) shl 8
        if i + 1 < data.len:
            temp += data[i + 1]

        #Add the 5-bit value.
        res.add(
            uint8(
                temp.extractBits(bit mod 8, 5)
            )
        )

        #Increase the bit by 5.
        bit += 5

    #Set the result variable.
    result = cast[Base32](res)

#Base32 string to Base32 object.
func toBase32*(
    data: string
): Base32 {.forceCheck: [
    ValueError
].} =
    #Verify that the data string is a Base 32 string.
    if not data.isBase32():
        raise newException(ValueError, "Invalid Base32 number.")

    #Create a result variable.
    var res: seq[uint8] = @[]

    #Iterate over the data.
    for i in data:
        #Add the character's value.
        res.add(uint8(CHARACTERS.find(i)))

    #Set the result variable.
    result = cast[Base32](res)

#Base32 object to binary seq.
func toSeq*(
    dataArg: Base32
): seq[uint8] {.forceCheck: [].} =
    var
        #Extract the data.
        data: seq[uint8] = cast[seq[uint8]](dataArg)
        #Needed amount of bytes.
        needed: int = int(
            data.len / 8 * 5
        )

    #Create the result with enough bytes for the data.
    result = newSeq[uint8](needed)

    var
        #Bytes we've handled.
        bytes: int = 0
        #Bit we're working off of in the byte.
        bit: int = 0
        #Space left in the previous byte.
        space: int

    for i in data:
        #If we're adding the bits to only already existing bytes...
        if bit <= 3:
            #Shift the bits to the proper position and add them.
            result[bytes] += i shl (3 - bit)
        else:
            #Set the space var.
            space = 8 - bit
            #Clear the bits on the right and add it to the previous byte.
            result[bytes] += i shr (5 - space)
            #Shift the bits that didn't make it onto the previous byte into the proper position and add them.
            result[bytes + 1] += i shl (space + 3)

        #Advance the bit counter.
        bit = bit + 5
        #If we went past the size of a byte...
        if bit > 7:
            #Subtract 8 from the bit.
            bit -= 8
            #Increment the byte counter.
            bytes += 1

#Base32 object to Base32 string.
func `$`*(
    dataArg: Base32
): string {.forceCheck: [].} =
    #Extract the data.
    var data: seq[uint8] = cast[seq[uint8]](dataArg)

    #Iterate over every item in the seq.
    for i in data:
        #Add the item.
        result &= CHARACTERS[int(i)]
