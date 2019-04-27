#Errors lib.
import ../Errors

#Hash master type.
import HashCommon

#nimcrypto lib.
import nimcrypto

#Define the Hash Types.
type
    SHA3_256Hash* = HashCommon.Hash[256]
    SHA3_512Hash* = HashCommon.Hash[512]

#SHA3 256 hashing algorithm.
proc SHA3_256*(
    bytesArg: string
): SHA3_256Hash {.forceCheck: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return SHA3_256Hash(
            data: sha3_256.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = sha3_256.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#SHA3 512 hashing algorithm.
proc SHA3_512*(
    bytesArg: string
): SHA3_512Hash {.forceCheck: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return SHA3_512Hash(
            data: sha3_512.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = sha3_512.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#String to SHA3_256Hash.
func toSHA3_256Hash*(
    hash: string
): SHA3_256Hash {.forceCheck: [
    ValueError
].} =
    try:
        result = hash.toHash(256)
    except ValueError as e:
        fcRaise e

#String to SHA3_512Hash.
func toSHA3_512Hash*(
    hash: string
): SHA3_512Hash {.forceCheck: [
    ValueError
].} =
    try:
        result = hash.toHash(512)
    except ValueError as e:
        fcRaise e
