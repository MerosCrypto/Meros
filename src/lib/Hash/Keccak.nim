#Hash master type.
import HashCommon

#nimcrypto lib.
import nimcrypto

#String utils standard lib.
import strutils

#Define the Hash Types.
type
    Keccak_256Hash* = HashCommon.Hash[256]
    Keccak_512Hash* = HashCommon.Hash[512]

#Keccak 256 hashing algorithm.
proc Keccak_256*(bytesArg: string): Keccak_256Hash {.raises: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return Keccak_256Hash(
            data: keccak256.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = keccak256.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#Keccak 512 hashing algorithm.
proc Keccak_512*(bytesArg: string): Keccak_512Hash {.raises: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return Keccak_512Hash(
            data: keccak512.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = keccak512.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#String to Keccak_256Hash.
func toKeccak_256Hash*(hash: string): Keccak_256Hash {.raises: [ValueError].} =
    hash.toHash(256)

#String to Keccak_512Hash.
func toKeccak_512Hash*(hash: string): Keccak_512Hash {.raises: [ValueError].} =
    hash.toHash(512)
