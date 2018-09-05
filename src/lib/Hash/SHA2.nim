#nimcrypto lib.
import nimcrypto

#Empty ptr uint8.
var empty: ptr uint8

#SHA2 256 hash function.
proc SHA2_256*(bytesArg: string): string =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return $sha256.digest(empty, uint(bytes.len))

    #Digest the byte array.
    result = $sha256.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len))

#SHA2 512 hash function.
proc SHA2_512*(bytesArg: string): string =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return $sha512.digest(empty, uint(bytes.len))

    #Digest the byte array.
    result = $sha512.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len))
