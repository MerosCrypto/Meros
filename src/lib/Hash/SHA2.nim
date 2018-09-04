#nimcrypto lib.
import nimcrypto

#SHA2 256 hash function.
proc SHA2_256*(bytesArg: string): string =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #Digest the byte array.
    result = $sha256.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len))

#SHA2 512 hash function.
proc SHA2_512*(bytesArg: string): string =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #Digest the byte array.
    result = $sha512.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len))
