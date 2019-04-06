#Hash master type.
import HashCommon

#nimcrypto lib.
import nimcrypto

#String utils standard lib.
import strutils

#Define the Hash Types.
type
    SHA3_256Hash* = HashCommon.Hash[256]
    SHA3_384Hash* = HashCommon.Hash[384]

#SHA3 256 hashing algorithm.
proc SHA3_256*(bytesArg: string): SHA3_256Hash {.raises: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return SHA3_256Hash(
            data: sha3_256.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = sha3_256.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#SHA3 384 hashing algorithm.
proc SHA3_384*(bytesArg: string): SHA3_384Hash {.raises: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return SHA3_384Hash(
            data: sha3_384.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = sha3_384.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#String to SHA3_256Hash.
func toSHA3_256Hash*(hash: string): SHA3_256Hash {.raises: [ValueError].} =
    hash.toHash(256)

#String to SHA3_384Hash.
func toSHA3_384Hash*(hash: string): SHA3_384Hash {.raises: [ValueError].} =
    hash.toHash(384)
