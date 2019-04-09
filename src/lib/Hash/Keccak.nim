#Errors lib.
import ../Errors

#Hash master type.
import HashCommon

#nimcrypto lib.
import nimcrypto

#String utils standard lib.
import strutils

#Define the Hash Types.
type
    Keccak_256Hash* = HashCommon.Hash[256]
    Keccak_384Hash* = HashCommon.Hash[384]

#Keccak 256 hashing algorithm.
proc Keccak_256*(
    bytesArg: string
): Keccak_256Hash {.forceCheck: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return Keccak_256Hash(
            data: keccak256.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = keccak256.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#Keccak 384 hashing algorithm.
proc Keccak_384*(
    bytesArg: string
): Keccak_384Hash {.forceCheck: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return Keccak_384Hash(
            data: keccak384.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = keccak384.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#String to Keccak_256Hash.
proc toKeccak_256Hash*(
    hash: string
): Keccak_256Hash {.forceCheck: [
    ValueError
].} =
    try:
        result = hash.toHash(256)
    except ValueError:
        fcRaise ValueError

#String to Keccak_384Hash.
proc toKeccak_384Hash*(
    hash: string
): Keccak_384Hash {.forceCheck: [
    ValueError
].} =
    try:
        result = hash.toHash(384)
    except ValueError:
        fcRaise ValueError
