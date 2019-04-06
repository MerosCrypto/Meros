#Hash master type.
import HashCommon

#nimcrypto lib.
import nimcrypto

#String utils standard lib.
import strutils

#Define the Hash Types.
type
    SHA2_256Hash* = Hash[256]
    SHA2_384Hash* = Hash[384]

#SHA2 256 hash function.
proc SHA2_256*(bytesArg: string): SHA2_256Hash {.raises: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return SHA2_256Hash(
            data: sha256.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = sha256.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#SHA2 384 hash function.
proc SHA2_384*(bytesArg: string): SHA2_384Hash {.raises: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return SHA2_384Hash(
            data: sha384.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = sha384.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#String to SHA2_256Hash.
func toSHA2_256Hash*(hash: string): SHA2_256Hash {.raises: [ValueError].} =
    hash.toHash(256)

#String to SHA2_384Hash.
func toSHA2_384Hash*(hash: string): SHA2_384Hash {.raises: [ValueError].} =
    hash.toHash(384)
