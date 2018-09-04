#nimcrypto lib.
import nimcrypto

#RIPEMD 160 hash function.
proc RipeMD_160*(bytesArg: string): string =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #Digest the byte array.
    result = $ripemd160.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len))
