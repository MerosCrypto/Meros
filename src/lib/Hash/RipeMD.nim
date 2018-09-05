#nimcrypto lib.
import nimcrypto

#Empty ptr uint8.
var empty: ptr uint8

#RIPEMD 160 hash function.
proc RipeMD_160*(bytesArg: string): string =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return $ripemd160.digest(empty, uint(bytes.len))

    #Digest the byte array.
    result = $ripemd160.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len))
