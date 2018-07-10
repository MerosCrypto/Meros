#nimcrypto lib.
import nimcrypto

#Standard string utils lib.
import strutils

#SHA512 context.
var ctx512: sha512
#SHA512 hash function.
proc SHA512*(hex: string): string =
    #Init the context.
    ctx512.init()

    #Create the 'byte array'.
    var bytes: string = ""
    #Turn the hex string into a byte array.
    for i in countup(0, hex.len-1, 2):
        bytes = bytes & ((char) parseHexInt(hex[i .. i + 1]))

    #Digest the byte array.
    result = $sha512.digest(cast[ptr uint8](addr bytes[0]), (uint) bytes.len)
    #Clear the context.
    ctx512.clear()

#Hash *exponent*. Used to generate SHA512 Squared and Cubed hashes.
func `^`*(hash: proc(hex: string): string, times: int): proc(x: string): string {.raises: [Exception].} =
    #If the exponent is less than or equal to 0, return "".
    if times <= 0:
        result = proc(x: string): string =
            result = ""
        return

    #Else, recursively hash the hex string and return that.
    return proc(hex: string): string {.raises: [Exception].} =
        result = hash(hex)

        for i in 1 ..< times:
            result = hash(result)
