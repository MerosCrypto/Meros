#Hash master type.
import HashCommon

#nimcrypto lib.
import nimcrypto

#String utils standard lib.
import strutils

#Define the Hash Type.
type Blake2_384Hash* = HashCommon.Hash[384]

#Blake 384 hashing algorithm.
proc Blake2_384*(bytesArg: string): Blake2_384Hash {.raises: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return Blake2_384Hash(
            data: blake2_384.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = blake2_384.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#String to Blake2_384Hash.
func toBlake2_384Hash*(hash: string): Blake2_384Hash {.raises: [ValueError].} =
    hash.toHash(384)
