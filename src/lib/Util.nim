#Times standard lib.
import times

#Gets the epoch and returns it as an int.
proc getTime*(): uint {.raises: [].} =
    uint(times.getTime().toUnix())

#Left-pads data, with a char or string, until the data is a certain length.
func pad*(
    data: string,
    len: int,
    prefix: char | string = char(0)
): string {.raises: [].} =
    result = data

    while result.len < len:
        result = prefix & result

#Converts a number to a binary string.
func toBinary*(
    number: SomeNumber
): string {.raises: [].} =
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

#Converts a binary string to a number.
func fromBinary*(
    number: string
): int {.raises: [].} =
    #Init the result variable.
    result = 0

    #Iterate over each byte.
    for b in 0 ..< number.len:
        #Add the byte after it's been properly shifted.
        result += int(number[b]) shl ((number.len - b - 1) * 8)

func `<..`*(a: int|uint, b: int|uint): Slice[uint] {.raises: [].} =
    (uint(a) + 1) .. uint(b)
