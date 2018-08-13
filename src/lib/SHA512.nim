#nimcrypto lib.
import nimcrypto

#Tests if a string is Hex or not.
import Base

#Hash exponentiation.
import Util
export Util

#Standard string utils lib.
import strutils

#SHA512 hash function.
proc SHA512*(bytesArg: string): string =
    var
        #Copy the bytes argument.
        bytes: string = bytesArg
        #SHA512 context.
        ctx512: sha512
    #Init the context.
    ctx512.init()

    #Digest the byte array.
    result = $sha512.digest(cast[ptr uint8](addr bytes[0]), (uint) bytes.len)
    #Clear the context.
    ctx512.clear()
