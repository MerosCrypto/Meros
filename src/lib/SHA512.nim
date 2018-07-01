import nimcrypto

import strutils

var ctx512: sha512
proc SHA512*(hex: string): string =
    ctx512.init()

    var ints: string = ""
    for i in countup(0, hex.len-1, 2):
        ints = ints & ((char) parseHexInt(hex[i .. i + 1]))
    result = $sha512.digest(cast[ptr uint8]((cstring) ints), (uint) ints.len)

    ctx512.clear()
