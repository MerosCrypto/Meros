import ../lib/RNG
import ../lib/SHA512
import ../lib/SECP256K1Wrapper

import strutils

type PrivateKey* = ref object of RootObj
    secret*: ptr array[32, uint8]

proc newPrivateKey*(): PrivateKey =
    result = PrivateKey(
        secret: cast[ptr array[32, uint8]](alloc0(32 * sizeof(uint8)))
    )

    result.secret[0 ..< 32] = random(32)[0 ..< 32]

proc newPrivateKey*(hex: string): PrivateKey =
    result = PrivateKey(
        secret: cast[ptr array[32, uint8]](alloc0(32 * sizeof(uint8)))
    )

    for i in countup(0, 63, 2):
        result.secret[(int) i / 2] = (uint8) parseHexInt($hex[i .. i + 1])

proc `$`*(key: PrivateKey): string =
    result = ""
    for i in 0 ..< 32:
        result = result & key.secret[i].toHex()

proc sign*(key: PrivateKey, msg: string): string =
    var hash: string = SHA512(msg)
    result = secpSign(hash, key.secret)
