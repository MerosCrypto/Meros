import ../lib/RNG
import ../lib/SECP256K1

import strutils

type PrivKey* = ref object of RootObj
    secret: array[32, uint8]

proc newPrivKey*(): PrivKey =
    result = PrivKey()
    result.secret[0..31] = random(32)[0..31]

proc newPrivKey*(hex: string): PrivKey =
    result = PrivKey()
    for i in countup(0, 63, 2):
        result.secret[(int) i/2] = (uint8) parseHexInt($hex[i] & $hex[i+1])

proc `$`*(key: PrivKey): string =
    result = ""
    for i in 0 ..< 32:
        result = result & key.secret[i].toHex()

proc sign*(key: PrivKey, hex: string): string =
    result = ""
