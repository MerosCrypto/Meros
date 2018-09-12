#Hash master type.
import HashCommon

#SHA3 Tiny lib.
import keccak_tiny

#String utils standard lib.
import strutils

#Define the Hash Types.
type
    SHA3_256Hash* = HashCommon.Hash[256]
    SHA3_512Hash* = HashCommon.Hash[512]

#SHA3 256 hashing algorithm.
proc SHA3_256*(input: string): SHA3_256Hash {.raises: [].} =
    SHA3_256Hash(
        data: keccak_tiny.sha3_256(input).data
    )

#SHA3 512 hashing algorithm.
proc SHA3_512*(input: string): SHA3_512Hash {.raises: [].} =
    SHA3_512Hash(
        data: keccak_tiny.sha3_512(input).data
    )

#String to SHA3_256Hash.
proc toSHA3_256Hash*(hex: string): SHA3_256Hash =
    for i in countup(0, hex.len - 1, 2):
        result.data[int(i / 2)] = uint8(parseHexInt(hex[i .. i + 1]))

#String to SHA3_512Hash.
proc toSHA3_512Hash*(hex: string): SHA3_512Hash =
    for i in countup(0, hex.len - 1, 2):
        result.data[int(i / 2)] = uint8(parseHexInt(hex[i .. i + 1]))
