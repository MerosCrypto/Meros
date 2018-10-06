#math standard lib.
import math

#Base32 characters.
const CHARACTERS: string = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

#Define the Base32 type.
type Base32* = distinct seq[uint8]

#Checks if the string is a valid Base32 string.
func isBase32*(data: string): bool {.raises: [].} =
    #Default return value of true.
    result = true

    #Iterate over the data.
    for i in data:
        #If the character is not in the character set...
        if CHARACTERS.find(i) == -1:
            #Return false.
            return false

#Binary array to Base32 object.
func toBase32*(data: openArray[uint8]): Base32 {.raises: [].} =
    #Creae a result variable.
    var res: seq[uint8] = @[]

    #How many times to run the loop.
    var count: int = (data.len * 8) div 5
    #If there's not an even amount of 5 bit numbers (which div doesn't handle as it truncates), add an extra count.
    if (data.len * 8) mod 5 != 0:
        inc(count)

    var
        #Byte we're using.
        index: int
        #Bit we're on.
        bit: int = 0
        #Temporary variable for the byte/the byte and the next one.
        temp: uint16

    #For each 5 bit variable...
    for _ in 0 ..< count:
        #Set the index.
        index = bit div 8

        #Set the temp variable.
        temp = uint16(data[index]) shl 8

        #If this bit set overflows into the next byte, and we can grab the next int...
        if (index < int((bit + 5) / 8)) and (index + 1 != data.len):
            temp += uint16(data[index + 1]) and 0xFF

        #Add the bits.
        res.add(
            uint8(
                temp shl (bit mod 8) shr 11
            )
        )

        #Increase the bit by 5.
        bit += 5

    #Set the result variable.
    result = cast[Base32](res)

#Base32 string to Base32 object.
func toBase32*(data: string): Base32 {.raises: [ValueError].} =
    #Verify that the data string is a Base 32 string.
    if not data.isBase32():
        raise newException(ValueError, "String is not a valid Base 32 number.")

    #Create a result variable.
    var res: seq[uint8] = @[]

    #Iterate over the data.
    for i in data:
        #Add the character's value.
        res.add(uint8(CHARACTERS.find(i)))

    #Set the result variable.
    result = cast[Base32](res)

#Base32 object to binary seq.
func toSeq*(dataArg: Base32): seq[uint8] {.raises: [].} =
    #Extract the data.
    var data: seq[uint8] = cast[seq[uint8]](dataArg)

    #Create the result with enough bytes for the data.
    result = newSeq[uint8](
        int(
            ceil(
                data.len / 8 * 5
            )
        )
    )

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
func `$`*(dataArg: Base32): string {.raises: [].} =
    #Extract the data.
    var data: seq[uint8] = cast[seq[uint8]](dataArg)

    #Create the empty result string.
    result = ""

    #Iterate over every item in the seq.
    for i in data:
        #Add the item.
        result &= CHARACTERS[int(i)]
