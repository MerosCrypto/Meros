#Hash master type.
import HashCommon

#Keccak Tiny lib.
import keccak_tiny

#String utils standard lib.
import strutils

#Define the Hash Types.
type
    Keccak_256Hash* = HashCommon.Hash[256]
    Keccak_512Hash* = HashCommon.Hash[512]

#Keccak 256 hashing algorithm.
proc Keccak_256*(input: string): Keccak_256Hash {.raises: [].} =
    Keccak_256Hash(
        data: keccak_tiny.keccak_256(input).data
    )

#Keccak 512 hashing algorithm.
proc Keccak_512*(input: string): Keccak_512Hash {.raises: [].} =
    Keccak_512Hash(
        data: keccak_tiny.keccak_512(input).data
    )

#String to Keccak_256Hash.
proc toKeccak_256Hash*(hex: string): Keccak_256Hash =
    for i in countup(0, hex.len - 1, 2):
        result.data[int(i / 2)] = uint8(parseHexInt(hex[i .. i + 1]))

#String to Keccak_512Hash.
proc toKeccak_512Hash*(hex: string): Keccak_512Hash =
    for i in countup(0, hex.len - 1, 2):
        result.data[int(i / 2)] = uint8(parseHexInt(hex[i .. i + 1]))
