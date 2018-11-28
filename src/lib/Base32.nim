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
        index: int
        #Temporary variable for the data.
        temp: uint16 = 0

    #For each 5 bit variable...
    for _ in 0 ..< count:
        #Set the index.
        index = bit div 8

        #Set temp.
        temp = uint16(data[index]) shl 8
        if index + 1 < data.len:
            temp += data[index + 1]
        #Add the byte.
        res.add(
            uint8(
                temp shl (bit mod 8) shr 11
            )
        )

        #Increase the bit by 5.
        bit += 5

    #Offset to correct for junk trailing zeros.
    #We do this because we can detect if leading zeros are junk but not if trailing ones are.
    #Also BTC compatibility.
    var offset: int = 5 - ((data.len * 8) mod 5)
    #If there is an offset...
    if offset != 5:
        #Shift every byte by the offset so the junk zeros at the end are now at the start.
        for i in countdown((res.len - 1), 0):
            res[i] = res[i] shr offset
            #if this isn't the first number...
            if i != 0:
                #Grab the last bits from the previous number and add them.
                res[i] += res[i-1] shl (8 - offset) shr 3

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
        bit: int = (needed * 8) - (data.len * 5)
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
