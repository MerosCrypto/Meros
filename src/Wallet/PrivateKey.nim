import ../lib/RNG
import ../lib/SHA512 as SHA512File
import ../lib/SECP256K1Wrapper

import strutils

type PrivateKey* = array[32, cuchar]

proc newPrivateKey*(): PrivateKey {.raises: [ValueError, Exception].} =
    for _ in 0 ..< 10:
        random(cast[ptr array[0, uint8]](addr result), 32)
        if secpPrivateKey(result):
            return

    raise newException(ValueError, "Couldn't generate a valid private key.")

proc newPrivateKey*(hex: string): PrivateKey {.raises: [ValueError].} =
    for i in countup(0, 63, 2):
        result[i div 2] = (cuchar) parseHexInt(hex[i .. i + 1])

    if secpPrivateKey(result) == false:
        raise newException(ValueError, "Private key is invalid.")

proc `$`*(key: PrivateKey): string {.raises: [].} =
    result = ""
    for i in 0 ..< 32:
        result = result & key[i].toHex()

proc sign*(key: PrivateKey, msg: string): string {.raises: [ValueError, Exception].} =
    result = key.secpSign((SHA512^2)(msg))
