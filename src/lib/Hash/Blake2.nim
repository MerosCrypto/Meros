#Errors lib.
import ../Errors

#Hash master type.
import HashCommon

#nimcrypto lib.
import nimcrypto

#Define the Hash Types.
type
    Blake2_256Hash* = HashCommon.Hash[256]
    Blake2_384Hash* = HashCommon.Hash[384]
    Blake2_512Hash* = HashCommon.Hash[512]

#Blake 256 hashing algorithm.
proc Blake2_256*(
    bytesArg: string
): Blake2_256Hash {.raises: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return Blake2_256Hash(
            data: blake2_256.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = blake2_256.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#Blake 384 hashing algorithm.
proc Blake2_384*(
    bytesArg: string
): Blake2_384Hash {.raises: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return Blake2_384Hash(
            data: blake2_384.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = blake2_384.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#Blake 512 hashing algorithm.
proc Blake2_512*(
    bytesArg: string
): Blake2_512Hash {.raises: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return Blake2_512Hash(
            data: blake2_512.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = blake2_512.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#String to Blake2_256Hash.
func toBlake2_256Hash*(
    hash: string
): Blake2_256Hash {.raises: [
    ValueError
].} =
    try:
        result = hash.toHash(256)
    except ValueError as e:
        raise e

#String to Blake2_384Hash.
func toBlake2_384Hash*(
    hash: string
): Blake2_384Hash {.raises: [
    ValueError
].} =
    try:
        result = hash.toHash(384)
    except ValueError as e:
        raise e

#String to Blake2_512Hash.
func toBlake2_512Hash*(
    hash: string
): Blake2_512Hash {.raises: [
    ValueError
].} =
    try:
        result = hash.toHash(512)
    except ValueError as e:
        raise e
