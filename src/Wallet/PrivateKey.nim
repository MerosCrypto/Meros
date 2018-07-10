import ../lib/RNG
import ../lib/SHA512 as SHA512File
import ../lib/SECP256K1Wrapper

import strutils

type PrivateKey* = array[32, uint8]

proc newPrivateKey*(): PrivateKey =
    random(cast[ptr array[0, uint8]](addr result), 32)

proc newPrivateKey*(hex: string): PrivateKey =
    for i in countup(0, 63, 2):
        result[(int) i / 2] = (uint8) parseHexInt($hex[i .. i + 1])

proc `$`*(key: PrivateKey): string =
    result = ""
    for i in 0 ..< 32:
        result = result & key[i].toHex()

proc sign*(key: PrivateKey, msg: string): string {.raises: [ValueError, Exception].} =
    result = key.secpSign((SHA512^2)(msg))
