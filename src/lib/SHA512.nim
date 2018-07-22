#nimcrypto lib.
import nimcrypto

#Hash exponentiation.
import Util
#For some reason, this wouldn't work with an upper case export.
export util

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
