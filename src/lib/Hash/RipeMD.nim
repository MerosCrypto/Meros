#Hash master type.
import HashCommon

#nimcrypto lib.
import nimcrypto

#String utils standard lib.
import strutils

#Define the Hash Type.
type RipeMD_160Hash* = Hash[160]

#RIPEMD 160 hash function.
proc RipeMD_160*(bytesArg: string): RipeMD_160Hash {.raises: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return RipeMD_160Hash(
            data: ripemd160.digest(empty, 0).data
        )

    #Digest the byte array.
    result = RipeMD_160Hash(
        data: ripemd160.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data
    )

#String to RipeMD_160Hash.
proc toRipeMD_160Hash*(hex: string): RipeMD_160Hash =
    for i in countup(0, hex.len - 1, 2):
        result.data[int(i / 2)] = uint8(parseHexInt(hex[i .. i + 1]))
