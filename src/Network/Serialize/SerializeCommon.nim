#Generates the length that's prefixed onto serialized strings.
func `lenPrefix`*(data: string): string {.raises: [].} =
    var
        #How many full bytes are needed to represent the length.
        full: int = int(data.len / 255)
        #How much of the length is left over after those full bytes.
        remainder: int = data.len mod 255
    #Add each full byte.
    for _ in 0 ..< full:
        result &= char(255)
    #Add the byte representing the remainding length.
    result &= char(remainder)

#Prepends a string with its length.
func `!`*(dataArg: string): string {.raises: [].} =
    #Extract the data argument.
    var data: string = dataArg

    #Strip leading 0s.
    while (data.len > 0) and (data[0] == char(0)):
        data = data.substr(1, data.len)

    #Return the data prefixed by it's length.
    result = data.lenPrefix & data

#Deseralizes a string by getting the length of the next byte, slicing that out, and moving on.
func deserialize*(
    data: string,
    estimated: int = 0
): seq[string] {.raises: [].} =
    #Allocate the seq.
    result = newSeq[string](estimated)

    var
        #Item we're on.
        item: int = 0
        #Location in the string.
        loc: int = 0
        #Size of the next element.
        size: int

    #While we're not at the end of string and we're still in the allocated set...
    while (loc < data.len) and (item < estimated):
        #Reset the size.
        size = 0

        #Go through full byte.
        while ord(data[loc]) == 255:
            #Add it to the size.
            size += ord(data[loc])
            #Increase the Location.
            inc(loc)
        #Add the current byte to the size (either the size/remainder).
        size += ord(data[loc])
        #Increase the location.
        inc(loc)

        #Get the result.
        result[item] = data[loc ..< loc + size]
        #Increase the item.
        inc(item)
        #Add the size to the loc.
        loc += size

    #While we're not at the end of string and we're not in the allocated set...
    while loc < data.len:
        #Do the exact same thing.
        size = 0

        while ord(data[loc]) == 255:
            size += ord(data[loc])
            inc(loc)
        size += ord(data[loc])
        inc(loc)

        #Add it to the seq at the end, don't set an 'existing' var.
        result.add(data[loc ..< loc + size])
        inc(item)
        loc += size

    #Shave off unused items.
    for i in item ..< estimated:
        result.delete(item)
