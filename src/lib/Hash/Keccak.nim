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
            data: keccak256.digest(empty, uint(bytes.len)).data
        )

    #Digest the byte array.
    result = Keccak_256Hash(
        data: keccak256.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data
    )

#Keccak 512 hashing algorithm.
proc Keccak_512*(bytesArg: string): Keccak_512Hash {.raises: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return Keccak_512Hash(
            data: keccak512.digest(empty, uint(bytes.len)).data
        )

    #Digest the byte array.
    result = Keccak_512Hash(
        data: keccak512.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data
    )

#String to Keccak_256Hash.
proc toKeccak_256Hash*(hex: string): Keccak_256Hash =
    for i in countup(0, hex.len - 1, 2):
        result.data[int(i / 2)] = uint8(parseHexInt(hex[i .. i + 1]))

#String to Keccak_512Hash.
proc toKeccak_512Hash*(hex: string): Keccak_512Hash =
    for i in countup(0, hex.len - 1, 2):
        result.data[int(i / 2)] = uint8(parseHexInt(hex[i .. i + 1]))
